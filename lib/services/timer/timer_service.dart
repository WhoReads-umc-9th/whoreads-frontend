import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/router/app_router.dart';
import '../../core/timer/timer_local_storage.dart';
import '../../models/reading_session_model.dart';
import 'foreground_service_manager.dart';
import 'timer_api_service.dart';

enum TimerRecoveryType {
  none,
  pausedWithLeft,
  pausedNoLeft,
  forceTerminated,
  timerCompleted,
}

class TimerService with ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;

  TimerService._internal() {
    _serviceManager.initService();
  }

  final TimerApiService _apiService = TimerApiService();
  final ForegroundServiceManager _serviceManager = ForegroundServiceManager();

  Timer? _heartbeatTimer;
  Timer? _localCountDownTimer;
  DateTime? _deadline;

  int _totalSettingSeconds = 0;
  int _currentSeconds = 0;

  bool _isRunning = false;
  bool _isStopping = false;
  bool _isRestoring = false;
  bool _isCheckingRecovery = false;
  int sessionId = -1;

  int elapsedSeconds = 0;
  int _pausedSecondsFromServer = 0;

  int get totalSeconds => _totalSettingSeconds;
  int get currentSeconds => _currentSeconds;
  bool get isRunning => _isRunning;
  bool get isStopping => _isStopping;
  bool get isRestoring => _isRestoring;
  int get pausedSeconds => _pausedSecondsFromServer;

  Future<void> checkOverlayPermission() async {
    if (!await FlutterForegroundTask.canDrawOverlays) {
      await FlutterForegroundTask.openSystemAlertWindowSettings();
    }
  }

  /// 💡 복구 상태 체크 마스터 엔진
  Future<TimerRecoveryType> checkRecoveryState() async {
    if (_isCheckingRecovery || _isBusy) return TimerRecoveryType.none;
    _isCheckingRecovery = true;
    _lastError = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = await _apiService.getActiveSession();
      if (active == null) {
        await _clearAll();
        return TimerRecoveryType.none;
      }
      sessionId = active.sessionId;
      _totalSettingSeconds =
          (active.totalReadMinutes + active.remainingMinutes) * 60;
      _currentSeconds = active.remainingMinutes * 60;
      _pausedSecondsFromServer = active.idleMinutes;
      final running =
          active.status == 'RUNNING' || active.status == 'IN_PROGRESS';
      final saved = prefs.getString('timer_session');
      if (saved != null) {
        try {
          final data = jsonDecode(saved);
          if (data['sessionId'] == sessionId) {
            _totalSettingSeconds = data['totalSeconds'] ?? _totalSettingSeconds;
            _currentSeconds =
                data['remainingSeconds'] ??
                (data['remainingMinutes'] ?? active.remainingMinutes) * 60;
            final savedAt = DateTime.tryParse(data['savedAt'] ?? '');
            // Pauses never consume time. Ignore a cache from another session.
            if (running && data['status'] != 'PAUSED' && savedAt != null) {
              final elapsed = DateTime.now().difference(savedAt).inSeconds;
              if (elapsed > 0) _currentSeconds -= elapsed;
            }
          }
        } catch (_) {
          // Corrupt/missing cache falls back to the server, not zero seconds.
        }
      }
      _currentSeconds = _currentSeconds.clamp(0, _totalSettingSeconds);
      elapsedSeconds = _totalSettingSeconds - _currentSeconds;
      if (_currentSeconds <= 0 && running) {
        await _apiService.completeTimer(sessionId);
        _isRunning = false;
        _isStopping = true;
        await _clearLocalSessionOnly(prefs);
        await _serviceManager.stop();
        _stopHeartbeat();
        _stopLocalTimer();
        notifyListeners();
        return TimerRecoveryType.timerCompleted;
      }
      _isRunning = running;
      _isStopping = !running;
      if (running) {
        _startLocalTimer();
        _startHeartbeat();
      } else {
        _stopLocalTimer();
        _stopHeartbeat();
      }
      await _saveCurrentSession();
      notifyListeners();
      if (active.status == 'PAUSED' || running) return TimerRecoveryType.none;
      if (active.idleMinutes > 120) return TimerRecoveryType.forceTerminated;
      return _currentSeconds > 0
          ? TimerRecoveryType.pausedWithLeft
          : TimerRecoveryType.pausedNoLeft;
    } catch (e) {
      _reportFailure();
      return TimerRecoveryType.none;
    } finally {
      _isCheckingRecovery = false;
    }
  }

  bool _isBusy = false;
  bool get isBusy => _isBusy;
  String? _lastError;
  String? get lastError => _lastError;

  void _reportFailure() {
    _lastError = '타이머를 저장하지 못했습니다. 연결을 확인하고 다시 시도해주세요.';
    notifyListeners();
  }

  Future<void> _saveCurrentSession() async {
    if (sessionId < 0) return;
    await TimerLocalStorage.instance.save(
      ActiveReadingSession(
        sessionId: sessionId,
        status: _isRunning ? 'RUNNING' : 'PAUSED',
        totalReadMinutes: elapsedSeconds ~/ 60,
        remainingMinutes: (_currentSeconds / 60).ceil(),
        idleMinutes: 0,
        focusBlockEnabled: false,
        whiteNoiseEnabled: false,
      ),
      remainingSeconds: _currentSeconds,
      totalSeconds: _totalSettingSeconds,
    );
  }

  Future<void> discardLocalSession() => _clearAll();

  /// 💡 복구 화면 연산 오케스트레이터
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
      int originalTotalMinutes =
          activeSession.totalReadMinutes + activeSession.remainingMinutes;
      _totalSettingSeconds = originalTotalMinutes * 60;

      if (_totalSettingSeconds <= 0) {
        await _apiService.completeTimer(activeSession.sessionId);
        await _clearAll();
        return;
      }

      bool targetRunning =
          activeSession.status == 'IN_PROGRESS' ||
          activeSession.status == 'RUNNING';
      _isStopping = activeSession.status == 'PAUSED';

      int calculatedCurrent =
          _totalSettingSeconds - (activeSession.totalReadMinutes * 60);

      // 🚨 계산된 잔여시간이 0 이하이면 즉시 완료 후 리턴
      if (calculatedCurrent <= 0) {
        await _apiService.completeTimer(activeSession.sessionId);
        await _clearAll();
        return;
      }

      final bool isServiceRunning =
          await FlutterForegroundTask.isRunningService;
      if (isServiceRunning) {
        _currentSeconds =
            await FlutterForegroundTask.getData<int>(key: 'currentSeconds') ??
            calculatedCurrent;
      } else {
        _currentSeconds = calculatedCurrent;
      }

      // 복구 후에도 currentSeconds가 0 이하이면 완주 처리
      if (_currentSeconds <= 0) {
        await _apiService.completeTimer(activeSession.sessionId);
        await _clearAll();
        return;
      }

      elapsedSeconds = _totalSettingSeconds - _currentSeconds;
      _isRunning = targetRunning;

      await _saveCurrentSession();

      if (_isRunning) {
        _startLocalTimer();
        if (!isServiceRunning) {
          await _serviceManager.start(
            currentSeconds: _currentSeconds,
            isRunning: true,
          );
          await _saveCurrentSession();
        }
        _startHeartbeat();
      }
    } catch (e) {
      _reportFailure();
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// 💡 포그라운드 카운트다운 루퍼
  void _startLocalTimer() {
    _stopLocalTimer();
    _deadline = DateTime.now().add(Duration(seconds: _currentSeconds));
    _localCountDownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!_isRunning) {
        _stopLocalTimer();
        return;
      }

      if (_currentSeconds > 0) {
        _currentSeconds =
            ((_deadline!.difference(DateTime.now()).inMilliseconds) / 1000)
                .ceil()
                .clamp(0, _totalSettingSeconds);
        elapsedSeconds = _totalSettingSeconds - _currentSeconds;
        notifyListeners();
      } else {
        _stopLocalTimer();
        _currentSeconds = 0;
        _isRunning = false;
        _isStopping = true;
        notifyListeners();
        AppRouter.navigatorKey.currentState?.pushNamed('/timer');
      }
    });
  }

  void _stopLocalTimer() {
    _localCountDownTimer?.cancel();
    _localCountDownTimer = null;
  }

  Future<void> startTimer() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastError = null;
    notifyListeners();
    try {
      if (_totalSettingSeconds <= 0 || _totalSettingSeconds > 7200) return;
      if (_isRunning) return;

      try {
        await checkOverlayPermission();
        final int targetMinutes = _totalSettingSeconds ~/ 60;

        await _apiService.setReadingSessionTime(totalMinutes: targetMinutes);
        final int responseSessionId = await _apiService.startTimer(
          totalMinutes: targetMinutes,
        );
        sessionId = responseSessionId;

        _currentSeconds = _totalSettingSeconds;
        _isRunning = true;
        _isStopping = false;

        final settingsResult = await _apiService.getReadingSessionSettings();
        bool serverFocusBlock = settingsResult?['focus_block_enabled'] ?? false;
        bool serverWhiteNoise = settingsResult?['white_noise_enabled'] ?? false;

        await _serviceManager.start(
          currentSeconds: _currentSeconds,
          isRunning: true,
        );
        await _saveCurrentSession();

        await TimerLocalStorage.instance.save(
          ActiveReadingSession(
            sessionId: sessionId,
            status: 'RUNNING',
            totalReadMinutes: 0,
            remainingMinutes: targetMinutes,
            idleMinutes: 0,
            focusBlockEnabled: serverFocusBlock,
            whiteNoiseEnabled: serverWhiteNoise,
          ),
          remainingSeconds: _currentSeconds,
          totalSeconds: _totalSettingSeconds,
        );

        _startLocalTimer();
        _startHeartbeat();
        notifyListeners();
      } catch (e) {
        _reportFailure();
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> handleResumeAction() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastError = null;
    notifyListeners();
    try {
      if (sessionId == -1) return;
      try {
        await _apiService.recoverTimer(sessionId);
        _isRunning = true;
        _isStopping = false;

        final settingsResult = await _apiService.getReadingSessionSettings();
        bool serverFocusBlock = settingsResult?['focus_block_enabled'] ?? false;
        bool serverWhiteNoise = settingsResult?['white_noise_enabled'] ?? false;

        await TimerLocalStorage.instance.save(
          ActiveReadingSession(
            sessionId: sessionId,
            status: 'RUNNING',
            totalReadMinutes: elapsedSeconds ~/ 60,
            remainingMinutes: _currentSeconds ~/ 60,
            idleMinutes: 0,
            focusBlockEnabled: serverFocusBlock,
            whiteNoiseEnabled: serverWhiteNoise,
          ),
          remainingSeconds: _currentSeconds,
          totalSeconds: _totalSettingSeconds,
        );

        await _serviceManager.start(
          currentSeconds: _currentSeconds,
          isRunning: true,
        );
        await _saveCurrentSession();

        _startLocalTimer();
        _startHeartbeat();
        notifyListeners();
      } catch (e) {
        _reportFailure();
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> handleReflectAction() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastError = null;
    notifyListeners();
    try {
      if (sessionId == -1) {
        await _clearAll();
        return;
      }
      try {
        await _apiService.reflectTimer(sessionId);
        await _clearAll();
      } catch (e) {
        _reportFailure();
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> handleExitAction() async {
    await completeTimer();
  }

  Future<void> pauseTimer() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastError = null;
    notifyListeners();
    try {
      if (!_isRunning || sessionId == -1) return;
      try {
        await _apiService.pauseTimer(sessionId);
        _isRunning = false;
        _isStopping = true;
        _stopLocalTimer();
        await _serviceManager.start(
          currentSeconds: _currentSeconds,
          isRunning: false,
        );
        await _saveCurrentSession();

        _stopHeartbeat();
        notifyListeners();
      } catch (e) {
        _reportFailure();
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> resumeTimer() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastError = null;
    notifyListeners();
    try {
      if (_isRunning || sessionId == -1) return;
      try {
        await _apiService.resumeTimer(sessionId);
        _isRunning = true;
        _isStopping = false;
        await _serviceManager.start(
          currentSeconds: _currentSeconds,
          isRunning: true,
        );
        await _saveCurrentSession();

        _startLocalTimer();
        _startHeartbeat();
        notifyListeners();
      } catch (e) {
        _reportFailure();
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> completeTimer() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastError = null;
    notifyListeners();
    try {
      if (sessionId == -1) {
        await _clearAll();
        return;
      }
      try {
        await _apiService.completeTimer(sessionId);
        await _clearAll();
      } catch (e) {
        _reportFailure();
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> cancelTimer() async {
    await completeTimer();
  }

  Future<void> resetTimer() async {
    await cancelTimer();
  }

  void onTimeSelected(int minutes) {
    if (_isRunning) return;
    _totalSettingSeconds = minutes * 60;
    _currentSeconds = _totalSettingSeconds;
    notifyListeners();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
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

  Future<void> _clearLocalSessionOnly(SharedPreferences prefs) async {
    await prefs.remove('timer_session');
    await TimerLocalStorage.instance.clear();
  }

  Future<void> _clearAll() async {
    _stopLocalTimer();
    _stopHeartbeat();
    _totalSettingSeconds = 0;
    _currentSeconds = 0;
    elapsedSeconds = 0;
    _isRunning = false;
    _isStopping = false;
    sessionId = -1;

    final prefs = await SharedPreferences.getInstance();
    await _clearLocalSessionOnly(prefs);
    await _serviceManager.stop();
    notifyListeners();
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void handleForegroundData(dynamic data) {
    if (data is int && _isRunning) {
      _currentSeconds = data.clamp(0, _totalSettingSeconds);
      elapsedSeconds = _totalSettingSeconds - _currentSeconds;
      notifyListeners();
    } else if (data is String) {
      switch (data) {
        case 'NOTI_BACKGROUND_COMPLETE':
          String? currentRouteName;
          AppRouter.navigatorKey.currentState?.popUntil((route) {
            currentRouteName = route.settings.name;
            return true;
          });
          if (currentRouteName == '/timer') {
            notifyListeners();
          } else {
            notifyListeners();
            AppRouter.navigatorKey.currentState?.pushNamed('/timer');
          }
          break;
        case 'NOTI_ACTION_PAUSE':
          pauseTimer();
          break;
        case 'NOTI_ACTION_RESUME':
          resumeTimer();
          break;
        case 'NOTI_ACTION_STOP':
          completeTimer();
          break;
      }
    }
  }
}
