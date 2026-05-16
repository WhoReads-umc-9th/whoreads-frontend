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
        enableVibration: true,
        playSound: false
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> start({required int currentSeconds}) async {
    await FlutterForegroundTask.saveData(key: 'currentSeconds', value: currentSeconds);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: '독서 타이머',
        notificationText: '타이머 측정 중입니다.',
        callback: startCallback,
      );
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
}