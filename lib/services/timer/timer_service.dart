import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'timer_api_service.dart';

class TimerService with ChangeNotifier {
  final TimerApiService _apiService = TimerApiService();
  Timer? _timer;
  int _totalSeconds = 0;
  int _currentSeconds = 0;
  bool _isRunning = false;
  bool _isStopping = false;
  int sessionId = -1;

  int get totalSeconds => _totalSeconds;
  int get currentSeconds => _currentSeconds;
  bool get isRunning => _isRunning;
  bool get isStopping => _isStopping;

  void _runTimer() {
    _isRunning = true;
    _isStopping = false;
    // 싱글 톤
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        _currentSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _isRunning = false;
      }
    });
  }

  Future<void> startTimer() async {
    if (_totalSeconds <= 0 || _totalSeconds > 120) return;
    // 타이머 시작
    _runTimer();
    sessionId = await _apiService.startTimer();
  }

  void resumeTimer() async {
    // 타이머 재개
    _runTimer();
    if (sessionId != -1) {
      await _apiService.resumeTimer(sessionId);
    }
  }

  void pauseTimer() async {
    // 타이머 멈춤
    _timer?.cancel();
    _isStopping = true;
    notifyListeners();
    if (sessionId != -1) {
      await _apiService.pauseTimer(sessionId);
    }
  }

  void resetTimer() async {
    _timer?.cancel();
    _isStopping = false;
    _isRunning = false;
    notifyListeners();
    if (sessionId != -1) {
      await _apiService.completeTimer(sessionId);
    }
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void onTimeSelected(int minutes) {
    _totalSeconds = minutes * 60;
    _currentSeconds = _totalSeconds;
    notifyListeners();
  }
}
