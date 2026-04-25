import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:whoreads/services/timer/foreground_service.dart';

class ForegroundServiceManager {
  static final ForegroundServiceManager _instance =
  ForegroundServiceManager._internal();

  factory ForegroundServiceManager() => _instance;

  ForegroundServiceManager._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await requestPermissions();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'whoreads_timer',
        channelName: '독서 타이머',
        channelDescription: '독서 타이머용 알림 채널.',
        priority: NotificationPriority.HIGH,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: true,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.repeat(1000),
      ),
    );

    _initialized = true;
  }

  Future<ServiceRequestResult> start({
    String title = '독서타이머',
    required String timerText,
    String text = '타이머 측정 중입니다.',
  }) async {
    await init();

    debugPrint('포그라운드 시작됨 $timerText');

    final isRunning = await FlutterForegroundTask.isRunningService;

    if (isRunning) {
      await update(
        title: title,
        timerText: timerText,
        text: text,
      );

      return const ServiceRequestSuccess();
    }

    return FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: '$title   $timerText',
      notificationText: text,
      callback: startCallback,
      serviceTypes: const [
        ForegroundServiceTypes.dataSync,
      ],
      notificationButtons: const [
        NotificationButton(id: 'cancel', text: '취소'),
        NotificationButton(id: 'pause', text: '일시정지'),
      ],
    );
  }

  Future<void> update({
    String title = '독서타이머',
    required String timerText,
    String text = '타이머 측정 중입니다.',
    bool isPaused = false,
  }) async {
    final isRunning = await FlutterForegroundTask.isRunningService;

    if (!isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: '$title   $timerText',
      notificationText: text,
      notificationButtons: [
        const NotificationButton(id: 'cancel', text: '취소'),
        NotificationButton(
          id: isPaused ? 'resume' : 'pause',
          text: isPaused ? '계속' : '일시정지',
        ),
      ],
    );
  }

  Future<void> stop() async {
    final isRunning = await FlutterForegroundTask.isRunningService;

    if (!isRunning) return;

    await FlutterForegroundTask.stopService();
  }

  static Future<void> requestPermissions() async {
    final permission =
    await FlutterForegroundTask.checkNotificationPermission();

    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      final ignoring =
      await FlutterForegroundTask.isIgnoringBatteryOptimizations;

      if (!ignoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }
}