import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../core/timer/timer_local_storage.dart';
import 'foreground_service_manager.dart';
import 'timer_api_service.dart';

class TimerService with ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;

  TimerService._internal() {
    _serviceManager.initService();
  }

  final TimerApiService _apiService = TimerApiService();
  final ForegroundServiceManager _serviceManager = ForegroundServiceManager();

  Timer? _heartbeatTimer;

  int _totalSeconds = 0;
  int _currentSeconds = 0;

  bool _isRunning = false;
  bool _isStopping = false;
  bool _isRestoring = false;
  int sessionId = -1;

  int get totalSeconds => _totalSeconds;
  int get currentSeconds => _currentSeconds;
  bool get isRunning => _isRunning;
  bool get isStopping => _isStopping;
  bool get isRestoring => _isRestoring;

  Future<void> checkOverlayPermission() async {
    if (!await FlutterForegroundTask.canDrawOverlays) {
      await FlutterForegroundTask.openSystemAlertWindowSettings();
    }
  }

  Future<void> restore() async {
    if (_isRestoring) return;
    _isRestoring = true;
    notifyListeners();

    try {
      final activeSession = await _apiService.getActiveSession();

      if (activeSession == null) {
        await _clearAll();
        return;
      }

      if (activeSession.idleMinutes > 120) {
        await _apiService.completeTimer(activeSession.sessionId);
        await _clearAll();
        return;
      }

      sessionId = activeSession.sessionId;
      _totalSeconds = activeSession.remainingMinutes * 60;

      if (_totalSeconds <= 0) {
        await _apiService.completeTimer(activeSession.sessionId);
        await _clearAll();
        return;
      }

      debugPrint('TimerService restore 성공: $activeSession');

      final bool isServiceRunning = await FlutterForegroundTask.isRunningService;

      debugPrint('TimerService restore 성공 후 isServiceRunning: $isServiceRunning');
      debugPrint('TimerService restore 성공 후 currentSeconds: '
          '${await FlutterForegroundTask.getData<int>(key: 'currentSeconds')}');

      if (isServiceRunning) {
        _currentSeconds = await FlutterForegroundTask.getData<int>(key: 'currentSeconds') ?? _totalSeconds;
      } else {
        _currentSeconds = _totalSeconds;
      }
      debugPrint('TimerService restore 성공 후 currentSeconds: $_currentSeconds');

      _isRunning = activeSession.status == 'IN_PROGRESS' || activeSession.status == 'RUNNING';
      _isStopping = activeSession.status == 'PAUSED';

      await TimerLocalStorage.instance.save(activeSession);

      if (_isRunning) {
        if (!isServiceRunning) {
          await _serviceManager.start(currentSeconds: _currentSeconds);
        }
        _startHeartbeat();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('TimerService restore 실패: $e');
      await _clearAll();
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> startTimer() async {
    if (_totalSeconds <= 0 || _totalSeconds > 7200) return;
    if (_isRunning) return;

    try {
      final int targetMinutes = _totalSeconds ~/ 60;

      debugPrint('TimerService startTimer 호출: $targetMinutes');
      await _apiService.setReadingSessionTime(totalMinutes: targetMinutes);

      final int responseSessionId = await _apiService.startTimer(totalMinutes: targetMinutes);
      sessionId = responseSessionId;

      _currentSeconds = _totalSeconds;
      _isRunning = true;
      _isStopping = false;

      await _serviceManager.start(currentSeconds: _currentSeconds);

      _startHeartbeat();
      notifyListeners();
    } catch (e) {
      debugPrint('TimerService startTimer 실패: $e');
    }
  }

  Future<void> pauseTimer() async {
    if (!_isRunning || sessionId == -1) return;

    try {
      _isRunning = false;
      _isStopping = true;
      await _apiService.pauseTimer(sessionId);
      FlutterForegroundTask.sendDataToTask({
        "type": "pause"
      });
      _stopHeartbeat();

      notifyListeners();
    } catch (e) {
      debugPrint('TimerService pauseTimer 실패: $e');
    }
  }

  Future<void> resumeTimer() async {
    if (_isRunning || sessionId == -1) return;

    try {
      await _apiService.resumeTimer(sessionId);

      _isRunning = true;
      _isStopping = false;

      await _serviceManager.start(currentSeconds: _currentSeconds);
      FlutterForegroundTask.sendDataToTask({
        "type": "resume"
      });
      _startHeartbeat();

      notifyListeners();
    } catch (e) {
      debugPrint('TimerService resumeTimer 실패: $e');
    }
  }

  Future<void> completeTimer() async {
    if (sessionId == -1) {
      await _clearAll();
      return;
    }
    try {
      await _apiService.completeTimer(sessionId);
    } catch (e) {
      debugPrint('TimerService completeTimer 실패: $e');
    } finally {
      await _clearAll();
    }
  }

  Future<void> cancelTimer() async {
    await completeTimer();
    await _clearAll();
  }

  Future<void> resetTimer() async {
    await cancelTimer();
  }

  void onTimeSelected(int minutes) {
    if (_isRunning) return;
    _totalSeconds = minutes * 60;
    _currentSeconds = _totalSeconds;
    notifyListeners();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!_isRunning || sessionId == -1) return;
      try {
        await _apiService.heartbeat(sessionId);
      } catch (e) {
        debugPrint('TimerService heartbeat 실패: $e');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _clearAll() async {
    _stopHeartbeat();
    _totalSeconds = 0;
    _currentSeconds = 0;
    _isRunning = false;
    _isStopping = false;
    sessionId = -1;

    await TimerLocalStorage.instance.clear();
    await _serviceManager.stop();
    notifyListeners();
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

    void handleForegroundData(dynamic data) {
      if (data is int) {
        if (data == -1) {
          completeTimer();
        } else {
          _currentSeconds = data;
          notifyListeners();
        }
      }
    }
  }
