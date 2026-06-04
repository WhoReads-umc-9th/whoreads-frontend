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
  timerCompleted
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
    if (_isCheckingRecovery) {
      debugPrint('⚠️ [checkRecoveryState] 이미 마감/복구 연산이 진행 중이므로 중복 요청을 바이패스합니다.');
      return TimerRecoveryType.none;
    }

    _isCheckingRecovery = true;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('timer_session');

    try {
      final activeSession = await _apiService.getActiveSession();

      if (activeSession == null) {
        await _clearAll();
        _isCheckingRecovery = false;
        return TimerRecoveryType.none;
      }

      sessionId = activeSession.sessionId;

      if (activeSession.status == 'IN_PROGRESS' ||
          activeSession.status == 'RUNNING' ||
          activeSession.status == 'PAUSED') {

        int localRemainingSeconds = _currentSeconds;

        if (localRemainingSeconds <= 0 && jsonString != null) {
          final localData = jsonDecode(jsonString);
          final String? savedAtStr = localData['savedAt'];
          if (savedAtStr != null) {
            final savedAt = DateTime.parse(savedAtStr);
            final int elapsedOutsideSeconds = DateTime.now().difference(savedAt).inSeconds;
            localRemainingSeconds = ((localData['remainingMinutes'] ?? 0) * 60) - elapsedOutsideSeconds;
          } else {
            localRemainingSeconds = (localData['remainingMinutes'] ?? 0) * 60;
          }
        }

        if (jsonString != null) {
          final localData = jsonDecode(jsonString);
          int localTotalMinutes = (localData['totalReadMinutes'] ?? 0) + (localData['remainingMinutes'] ?? 0);
          _totalSettingSeconds = localTotalMinutes * 60;
        }

        bool isServerZero = activeSession.remainingMinutes <= 0;
        bool isLocalZero = localRemainingSeconds <= 0;

        if (activeSession.status == 'IN_PROGRESS' && isServerZero && isLocalZero) {
          debugPrint('🏁 [메모리 코어 마감] 서버 0분 및 실시간 메모리 변수 마감 확인 ➔ 종료 선처리 진행');

          await _apiService.completeTimer(sessionId);

          _currentSeconds = 0;
          elapsedSeconds = _totalSettingSeconds;
          _isRunning = false;
          _isStopping = true;

          await _clearLocalSessionOnly(prefs);

          notifyListeners();
          _isCheckingRecovery = false;
          return TimerRecoveryType.timerCompleted;
        }
        else if (localRemainingSeconds <= 0) {
          debugPrint('⏳ [백업 마감선 작동] 메모리 잔여 시간 소실 확인 ➔ 타이머 즉시 마감');
          _currentSeconds = 0;
          elapsedSeconds = _totalSettingSeconds;
          _isRunning = false;
          _isStopping = true;
          await completeTimer();
          _isCheckingRecovery = false;
          return TimerRecoveryType.timerCompleted;
        }
        else {
          debugPrint('⏳ [실시간 싱크 전개] 디스크 캐시 우회 -> 현재 살아있는 정밀 메모리 초 반영: ${localRemainingSeconds}초');
          _currentSeconds = localRemainingSeconds;
          elapsedSeconds = _totalSettingSeconds - _currentSeconds;

          if (activeSession.status == 'PAUSED') {
            _isRunning = false;
            _isStopping = true;
            _stopLocalTimer();
          } else {
            _isRunning = true;
            _isStopping = false;
            _startLocalTimer();
          }

          await TimerLocalStorage.instance.save(activeSession);
          _isCheckingRecovery = false;
          return TimerRecoveryType.none;
        }
      }

      _pausedSecondsFromServer = activeSession.idleMinutes;
      int serverTotalMinutes = activeSession.totalReadMinutes + activeSession.remainingMinutes;
      _totalSettingSeconds = serverTotalMinutes * 60;
      elapsedSeconds = activeSession.totalReadMinutes * 60;

      _isRunning = false;
      _isStopping = true;
      _stopLocalTimer();
      await _serviceManager.stop();
      _stopHeartbeat();

      if (_pausedSecondsFromServer > 120) {
        _isCheckingRecovery = false;
        return TimerRecoveryType.forceTerminated;
      }

      int remainSeconds = _totalSettingSeconds - elapsedSeconds;
      if (remainSeconds > 0) {
        _currentSeconds = remainSeconds;
        _isCheckingRecovery = false;
        return TimerRecoveryType.pausedWithLeft;
      } else {
        _currentSeconds = 0;
        await _clearLocalSessionOnly(prefs);
        _isCheckingRecovery = false;
        return TimerRecoveryType.timerCompleted;
      }
    } catch (e) {
      debugPrint('CheckRecoveryState 도중 예외 발생: $e');
      _isCheckingRecovery = false;
      return TimerRecoveryType.none;
    }
  }

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
      int originalTotalMinutes = activeSession.totalReadMinutes + activeSession.remainingMinutes;
      _totalSettingSeconds = originalTotalMinutes * 60;

      if (_totalSettingSeconds <= 0) {
        await _apiService.completeTimer(activeSession.sessionId);
        await _clearAll();
        return;
      }

      bool targetRunning = activeSession.status == 'IN_PROGRESS' || activeSession.status == 'RUNNING';
      _isStopping = activeSession.status == 'PAUSED';

      int calculatedCurrent = _totalSettingSeconds - (activeSession.totalReadMinutes * 60);

      final bool isServiceRunning = await FlutterForegroundTask.isRunningService;
      if (isServiceRunning) {
        _currentSeconds = await FlutterForegroundTask.getData<int>(key: 'currentSeconds') ?? calculatedCurrent;
      } else {
        _currentSeconds = calculatedCurrent;
      }

      elapsedSeconds = _totalSettingSeconds - _currentSeconds;
      _isRunning = targetRunning;

      await TimerLocalStorage.instance.save(activeSession);

      if (_isRunning) {
        _startLocalTimer();
        if (!isServiceRunning) {
          await _serviceManager.start(currentSeconds: _currentSeconds, isRunning: true);
        }
        _startHeartbeat();
      }
    } catch (e) {
      debugPrint('TimerService restore 실패: $e');
      await _clearAll();
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// 💡 포그라운드 카운트다운 루퍼
  void _startLocalTimer() {
    _stopLocalTimer();
    _localCountDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isRunning) {
        _stopLocalTimer();
        return;
      }

      if (_currentSeconds > 0) {
        _currentSeconds--;
        elapsedSeconds = _totalSettingSeconds - _currentSeconds;
        notifyListeners();
      } else {
        _stopLocalTimer();
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
    if (_totalSettingSeconds <= 0 || _totalSettingSeconds > 7200) return;
    if (_isRunning) return;

    await checkOverlayPermission();

    try {
      final int targetMinutes = _totalSettingSeconds ~/ 60;

      await _apiService.setReadingSessionTime(totalMinutes: targetMinutes);
      final int responseSessionId = await _apiService.startTimer(totalMinutes: targetMinutes);
      sessionId = responseSessionId;

      _currentSeconds = _totalSettingSeconds;
      _isRunning = true;
      _isStopping = false;

      final settingsResult = await _apiService.getReadingSessionSettings();
      bool serverFocusBlock = settingsResult?['focus_block_enabled'] ?? false;
      bool serverWhiteNoise = settingsResult?['white_noise_enabled'] ?? false;

      await _serviceManager.start(currentSeconds: _currentSeconds, isRunning: true);

      await TimerLocalStorage.instance.save(ActiveReadingSession(
        sessionId: sessionId,
        status: 'RUNNING',
        totalReadMinutes: 0,
        remainingMinutes: targetMinutes,
        idleMinutes: 0,
        focusBlockEnabled: serverFocusBlock,
        whiteNoiseEnabled: serverWhiteNoise,
      ));

      _startLocalTimer();
      _startHeartbeat();
      notifyListeners();
    } catch (e) {
      debugPrint('TimerService startTimer 실패: $e');
    }
  }

  Future<void> handleResumeAction() async {
    if (sessionId == -1) return;
    try {
      await _apiService.recoverTimer(sessionId);
      _isRunning = true;
      _isStopping = false;

      final settingsResult = await _apiService.getReadingSessionSettings();
      bool serverFocusBlock = settingsResult?['focus_block_enabled'] ?? false;
      bool serverWhiteNoise = settingsResult?['white_noise_enabled'] ?? false;

      await TimerLocalStorage.instance.save(ActiveReadingSession(
        sessionId: sessionId,
        status: 'RUNNING',
        totalReadMinutes: elapsedSeconds ~/ 60,
        remainingMinutes: _currentSeconds ~/ 60,
        idleMinutes: 0,
        focusBlockEnabled: serverFocusBlock,
        whiteNoiseEnabled: serverWhiteNoise,
      ));

      await _serviceManager.start(currentSeconds: _currentSeconds, isRunning: true);

      _startLocalTimer();
      _startHeartbeat();
      notifyListeners();
    } catch (e) {
      debugPrint('이어하기 API 처리 실패: $e');
    }
  }

  Future<void> handleReflectAction() async {
    if (sessionId == -1) {
      await _clearAll();
      return;
    }
    try {
      await _apiService.reflectTimer(sessionId);
    } catch (e) {
      debugPrint('TimerService reflectTimer 실패: $e');
    } finally {
      await _clearAll();
    }
  }

  Future<void> handleExitAction() async {
    await completeTimer();
  }

  Future<void> pauseTimer() async {
    if (!_isRunning || sessionId == -1) return;
    try {
      _isRunning = false;
      _isStopping = true;
      _stopLocalTimer();
      await _apiService.pauseTimer(sessionId);
      await _serviceManager.start(currentSeconds: _currentSeconds, isRunning: false);

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
      await _serviceManager.start(currentSeconds: _currentSeconds, isRunning: true);

      _startLocalTimer();
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
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
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
    if (data is int) {
      _currentSeconds = data;
      notifyListeners();
    }
    else if (data is String) {
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