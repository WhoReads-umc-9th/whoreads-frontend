import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class MyTimerHandler extends TaskHandler {
  Timer? _timer;
  int _currentSeconds = 0;

  bool _isPaused = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _currentSeconds =
        await FlutterForegroundTask.getData<int>(key: 'currentSeconds') ?? 1800;

    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isPaused) return;

      if (_currentSeconds > 0) {
        _currentSeconds--;

        await FlutterForegroundTask.saveData(
          key: 'currentSeconds',
          value: _currentSeconds,
        );

        FlutterForegroundTask.updateService(
          notificationTitle: '독서 타이머',
          notificationText:
          '타이머 측정 중입니다. ${_formatTime(_currentSeconds)}',
        );

        FlutterForegroundTask.sendDataToMain(_currentSeconds);
      } else {
        _timer?.cancel();
        FlutterForegroundTask.updateService(
          notificationTitle: '독서 타이머',
          notificationText: '타이머가 종료되었습니다.',
        );
        FlutterForegroundTask.sendDataToMain(-1);
      }
    });
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('onReceiveData: $data');
    if (data is Map) {
      switch (data['type']) {
        case 'pause':
          _pause();
          break;
        case 'resume':
          _resume();
          break;
        case 'stop':
          _stop();
          break;
      }
    }
  }

  void _pause() {
    _isPaused = true;
  }

  void _resume() {
    _isPaused = false;
  }

  void _stop() {
    _timer?.cancel();
    FlutterForegroundTask.stopService();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTimerHandler());
}