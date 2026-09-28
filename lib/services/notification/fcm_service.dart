import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationDestination {
  const NotificationDestination(this.route, [this.arguments]);
  final String route;
  final Object? arguments;
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final NotificationService _notificationService = NotificationService();
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenSubscription;
  static bool _initialized = false;
  static bool _navigationReady = false;
  static Map<String, dynamic>? _pendingData;

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    '중요 알림',
    description: '이 채널은 실시간 서비스 알림을 위해 사용됩니다.',
    importance: Importance.max,
  );

  static NotificationDestination? destinationFor(Map<String, dynamic> data) {
    if (data['type'] == 'ROUTINE')
      return const NotificationDestination('/library');
    dynamic link = data['link'] ?? data;
    if (link is String) {
      try {
        link = jsonDecode(link);
      } catch (_) {
        return null;
      }
    }
    if (data['type'] == 'FOLLOW' && link is Map) {
      final id = int.tryParse('${link['celebrity_id']}');
      if (id != null && id > 0)
        return NotificationDestination('/celebrity/book', id);
    }
    return null;
  }

  static Future<bool> requestNotificationPermission() async {
    var settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _setupForegroundNotifications();
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => handleNotificationData(m.data),
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _pendingData = initial.data;
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      try {
        _pendingData = Map<String, dynamic>.from(jsonDecode(payload));
      } catch (_) {}
    }
    _initialized = true;
  }

  static Future<void> initializeToken() async {
    if (!await requestNotificationPermission()) return;
    await _messaging.setAutoInitEnabled(true);
    await sendTokenToServer();
  }

  static Future<void> sendTokenToServer() async {
    try {
      if (!await requestNotificationPermission()) return;
      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
      _tokenSubscription ??= _messaging.onTokenRefresh.listen((token) async {
        try {
          await _registerToken(token);
        } catch (_) {
          debugPrint('FCM 등록 실패');
        }
      });
    } catch (_) {
      debugPrint('FCM 등록 실패');
    }
  }

  static Future<void> _registerToken(String token) async {
    if ((await TokenStorage.getAccessToken())?.isNotEmpty != true) return;
    await ApiClient.checked(
      ApiClient.dio.post('/members/me/fcm-tokens', data: {'fcm_token': token}),
    );
  }

  static Future<void> authenticatedNavigatorReady() async {
    _navigationReady = true;
    final pending = _pendingData;
    if (pending != null) await handleNotificationData(pending);
  }

  static Future<void> handleNotificationData(Map<String, dynamic> data) async {
    if (!_navigationReady ||
        AppRouter.navigatorKey.currentState == null ||
        (await TokenStorage.getAccessToken())?.isNotEmpty != true) {
      _pendingData = data;
      return;
    }
    _pendingData = null;
    final destination = destinationFor(data);
    if (destination == null) return;
    AppRouter.navigateTo(destination.route, arguments: destination.arguments);
    // Read-state failure should not prevent navigation or escape a stream callback.
    final id = data['id']?.toString();
    if (id != null && id.isNotEmpty) {
      try {
        await _notificationService.markAsRead(id);
        if (data['type'] == 'ROUTINE')
          await _notificationService.removeNotification(id);
      } catch (_) {
        debugPrint('알림 읽음 처리 실패');
      }
    }
  }

  static Future<void> clearSession() async {
    _navigationReady = false;
    _pendingData = null;
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    if (Firebase.apps.isEmpty) return;
    try {
      await _messaging.setAutoInitEnabled(false);
      await _messaging.deleteToken();
      await _localNotifications.cancelAll();
    } catch (_) {
      debugPrint('기기 알림 토큰 정리 실패');
    }
  }

  static Future<void> _setupForegroundNotifications() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (details) async {
        try {
          if (details.payload != null) {
            await handleNotificationData(
              Map<String, dynamic>.from(jsonDecode(details.payload!)),
            );
          }
        } catch (_) {
          debugPrint('알림 데이터 형식 오류');
        }
      },
    );
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      try {
        await _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: notification.android?.smallIcon,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: jsonEncode(message.data),
        );
      } catch (_) {
        debugPrint('알림 표시 실패');
      }
    });
  }
}
