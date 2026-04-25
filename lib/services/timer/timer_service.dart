import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../core/timer/timer_local_storage.dart';
import 'foreground_service_manager.dart';
import 'timer_api_service.dart';

class TimerService with ChangeNotifier {
  static final TimerService _instance = TimerService._internal();

  factory TimerService() => _instance;

  TimerService._internal();

  final TimerApiService _apiService = TimerApiService();
  final ForegroundServiceManager _serviceManager = ForegroundServiceManager();

  Timer? _timer;
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

      final foregroundRunning =
      await FlutterForegroundTask.isRunningService;

      sessionId = activeSession.sessionId;

      _totalSeconds = activeSession.remainingMinutes * 60;
      _currentSeconds = activeSession.remainingMinutes * 60;

      _isRunning = activeSession.status == 'RUNNING';
      _isStopping = activeSession.status == 'PAUSED';

      await TimerLocalStorage.instance.save(activeSession);

      if (_isRunning) {
        _runTimer();

        if (!foregroundRunning) {
          await _serviceManager.start(
            title: '독서 타이머',
            timerText: formatTime(_currentSeconds),
            text: '타이머 측정 중입니다.',
          );
        }

        _startHeartbeat();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('TimerService restore 실패: $e');

      final localSession = await TimerLocalStorage.instance.load();

      if (localSession != null) {
        sessionId = localSession.sessionId;
        _totalSeconds = localSession.remainingMinutes * 60;
        _currentSeconds = localSession.remainingMinutes * 60;
        _isRunning = localSession.status == 'RUNNING';
        _isStopping = localSession.status == 'PAUSED';

        if (_isRunning) {
          _runTimer();
          _startHeartbeat();
        }

        notifyListeners();
      }
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> startTimer() async {
    if (_totalSeconds <= 0 || _totalSeconds > 7200) return;
    if (_isRunning) return;

    try {
      final startedSession = await _apiService.startTimer(
        totalMinutes: _totalSeconds ~/ 60,
      );

      sessionId = startedSession.sessionId;

      _totalSeconds = startedSession.remainingMinutes * 60;
      _currentSeconds = startedSession.remainingMinutes * 60;

      _isRunning = true;
      _isStopping = false;

      await TimerLocalStorage.instance.save(startedSession);

      await _serviceManager.start(
        title: '독서 타이머',
        timerText: formatTime(_currentSeconds),
        text: '타이머 측정 중입니다.',
      );

      _runTimer();
      _startHeartbeat();

      notifyListeners();
    } catch (e) {
      debugPrint('TimerService startTimer 실패: $e');
    }
  }

  Future<void> pauseTimer() async {
    if (!_isRunning) return;
    if (sessionId == -1) return;

    _timer?.cancel();
    _timer = null;

    try {
      final pausedSession = await _apiService.pauseTimer(sessionId);

      _isRunning = false;
      _isStopping = true;

      _totalSeconds = pausedSession.remainingMinutes * 60;
      _currentSeconds = pausedSession.remainingMinutes * 60;

      await TimerLocalStorage.instance.save(pausedSession);

      await _serviceManager.update(
        title: '독서 타이머',
        timerText: formatTime(_currentSeconds),
        text: '일시정지됨',
      );

      _stopHeartbeat();

      notifyListeners();
    } catch (e) {
      debugPrint('TimerService pauseTimer 실패: $e');
    }
  }

  Future<void> resumeTimer() async {
    if (_isRunning) return;
    if (sessionId == -1) return;

    try {
      final resumedSession = await _apiService.resumeTimer(sessionId);

      _totalSeconds = resumedSession.remainingMinutes * 60;
      _currentSeconds = resumedSession.remainingMinutes * 60;

      _isRunning = true;
      _isStopping = false;

      await TimerLocalStorage.instance.save(resumedSession);

      await _serviceManager.start(
        title: '독서 타이머',
        timerText: formatTime(_currentSeconds),
        text: '타이머 측정 중입니다.',
      );

      _runTimer();
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
    if (sessionId != -1) {
      try {
        await _apiService.cancelTimer(sessionId);
      } catch (e) {
        debugPrint('TimerService cancelTimer 실패: $e');
      }
    }

    await _clearAll();
  }

  Future<void> resetTimer() async {
    await completeTimer();
  }

  void onTimeSelected(int minutes) {
    if (_isRunning) return;

    _totalSeconds = minutes * 60;
    _currentSeconds = _totalSeconds;

    notifyListeners();
  }

  void _runTimer() {
    _timer?.cancel();

    _isRunning = true;
    _isStopping = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_currentSeconds > 0) {
        _currentSeconds--;

        await _serviceManager.update(
          title: '독서 타이머',
          timerText: formatTime(_currentSeconds),
          text: '타이머 측정 중입니다.',
        );

        notifyListeners();
        return;
      }

      await completeTimer();
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();

    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 5),
          (_) async {
        if (!_isRunning || sessionId == -1) return;

        try {
          await _apiService.heartbeat(sessionId);
        } catch (e) {
          debugPrint('TimerService heartbeat 실패: $e');
        }
      },
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _clearAll() async {
    _timer?.cancel();
    _timer = null;

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
}