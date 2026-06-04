import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTimerHandler());
}
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

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain({
      'type': 'notification_pressed',
    });
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
          notificationText: '타이머 측정 중입니다. ${_formatTime(_currentSeconds)}',
        );

        FlutterForegroundTask.sendDataToMain(_currentSeconds);
      } else {
        _timer?.cancel();

        try {
          FlutterForegroundTask.wakeUpScreen();
          FlutterForegroundTask.launchApp('/timer');
        } catch (e) {
          debugPrint('백그라운드 앱 런칭 실패: $e');
        }

        FlutterForegroundTask.updateService(
          notificationTitle: '독서 타이머 완료',
          notificationText: '독서 타이머가 완료되었습니다.',
          notificationButtons: [
            const NotificationButton(id: 'action_stop', text: '확인'),
          ],
        );

        FlutterForegroundTask.sendDataToMain('NOTI_BACKGROUND_COMPLETE');
      }
    });
  }

  @override
  void onReceiveData(Object data) {
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

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    switch (id) {
      case 'action_pause':
        _pause();
        FlutterForegroundTask.sendDataToMain('NOTI_ACTION_PAUSE');
        break;
      case 'action_resume':
        _resume();
        FlutterForegroundTask.sendDataToMain('NOTI_ACTION_RESUME');
        break;
      case 'action_stop':
        _stop();
        FlutterForegroundTask.sendDataToMain('NOTI_ACTION_STOP');
        break;
    }
  }

  void _pause() {
    _isPaused = true;
    FlutterForegroundTask.updateService(
      notificationTitle: '독서 타이머',
      notificationText: '타이머가 중지되었습니다. ${_formatTime(_currentSeconds)}',
      notificationButtons: [
        const NotificationButton(id: 'action_resume', text: '다시시작'),
        const NotificationButton(id: 'action_stop', text: '종료하기'),
      ],
    );
  }

  void _resume() {
    _isPaused = false;
    FlutterForegroundTask.updateService(
      notificationTitle: '독서 타이머',
      notificationText: '타이머 측정 중입니다. ${_formatTime(_currentSeconds)}',
      notificationButtons: [
        const NotificationButton(id: 'action_pause', text: '일시정지'),
        const NotificationButton(id: 'action_stop', text: '종료하기'),
      ],
    );
  }

  void _stop() {
    _timer?.cancel();
    _isPaused = false;
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