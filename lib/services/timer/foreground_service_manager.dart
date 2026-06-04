import 'package:flutter/foundation.dart'; // 💡 로그(debugPrint) 활용을 위한 임포트
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'foreground_service.dart';

class ForegroundServiceManager {
  void initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'reading_timer_channel',
        channelName: '독서 타이머 알림',
        channelDescription: '독서 타이머가 백그라운드에서 동작할 때 알림을 제공합니다.',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.HIGH,
        enableVibration: false,
        showWhen: true,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  Future<void> start({required int currentSeconds, required bool isRunning}) async {
    await FlutterForegroundTask.saveData(key: 'currentSeconds', value: currentSeconds);

    List<NotificationButton> buttons = [];
    if (isRunning) {
      buttons = [
        const NotificationButton(id: 'action_pause', text: '일시정지'),
        const NotificationButton(id: 'action_stop', text: '종료하기'),
      ];
    } else {
      buttons = [
        const NotificationButton(id: 'action_resume', text: '다시시작'),
        const NotificationButton(id: 'action_stop', text: '종료하기'),
      ];
    }

    final String bodyText = isRunning
        ? '타이머 측정 중입니다. ${_formatTime(currentSeconds)}'
        : '타이머가 중지되었습니다. ${_formatTime(currentSeconds)}';

    if (await FlutterForegroundTask.isRunningService) {
      debugPrint('🔍 [ForegroundServiceManager] 이미 서비스 동작 중 -> updateService 실행');
      await FlutterForegroundTask.updateService(
        notificationTitle: '독서 타이머',
        notificationText: bodyText,
        notificationButtons: buttons,
      );
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: '독서 타이머',
        notificationText: bodyText,
        callback: startCallback,
        notificationInitialRoute: '/timer',
        notificationButtons: buttons,
      );
    }
  }

  Future<void> showCompleteNotification() async {
    if (await FlutterForegroundTask.isRunningService) {
      List<NotificationButton> completeButtons = [
        const NotificationButton(id: 'action_stop', text: '확인'),
      ];

      await FlutterForegroundTask.updateService(
        notificationTitle: '독서 타이머 완료',
        notificationText: '독서 타이머가 완료되었습니다.',
        notificationButtons: completeButtons,
      );
    } else {
      debugPrint('[ForegroundServiceManager] 서비스가 가동 중이 아니라 완료 알림을 띄우지 못함');
    }
  }

  Future<void> update({required String title, required String text}) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}