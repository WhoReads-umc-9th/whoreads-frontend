import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

import 'package:whoreads/core/router/app_router.dart';

import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("백그라운드 메시지 수신: ${message.messageId}");
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final NotificationService _notificationService = NotificationService();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    '중요 알림',
    description: '이 채널은 실시간 서비스 알림을 위해 사용됩니다.',
    importance: Importance.max,
    playSound: true,
  );

  /// 권한 확인 및 요청
  static Future<bool> requestNotificationPermission() async {
    NotificationSettings settings = await _messaging.getNotificationSettings();

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _setupForegroundNotifications();
  }

  static Future<void> initializeToken() async {
    bool isAuthorized = await requestNotificationPermission();
    _messaging.setAutoInitEnabled(true);
    if (!isAuthorized) return;
    sendTokenToServer();
  }

  /// 서버로 토큰 전송
  static Future<void> sendTokenToServer() async {
    try {
      bool isAuthorized = await requestNotificationPermission();
      if (!isAuthorized) return;

      String? token = await _messaging.getToken();
      if (token == null) return;

      await ApiClient.dio.post(
        "/members/me/fcm-tokens",
        data: {'fcm_token': token},
      );

      _messaging.onTokenRefresh.listen((newToken) async {
        await ApiClient.dio.post(
          "/members/me/fcm-tokens",
          data: {'fcm_token': newToken},
        );
      });
    } catch (e) {
      debugPrint("FCM 전송 에러: $e");
    }
  }

  static Future<void> _handleDeepLink(String type, dynamic linkData) async {
    final String? celebrityId = linkData['celebrity_id']?.toString();
    if (type == 'FOLLOW' && celebrityId != null) {
      AppRouter.navigateTo('/celebrity/book', arguments: celebrityId);
    } else if (type == 'ROUTINE') {
      AppRouter.navigateTo('/library');
    } else {
      debugPrint("⚠️ 알 수 없는 딥링크 타입: $type");
    }
  }

  static Future<void> _handleReadNotification(String type, String id) async {

    await _notificationService.markAsRead(id);

    if (type == 'ROUTINE') {
      await _notificationService.removeNotification(id);
    }
  }

  static Future<void> _setupForegroundNotifications() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        if (details.payload != null && details.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(details.payload!);

            final String? type = data['type'];

            final dynamic link = data['link'] ?? data;
            debugPrint("notification : ${data['id']}");
            _handleReadNotification(type ?? '', data['id']);
            _handleDeepLink(type ?? '', link ?? {});
          } catch (e) {
            debugPrint("클릭 데이터 처리 에러: $e");
          }
        }
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        debugPrint("Data Payload: ${message.data}");
      }

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: _channel.importance,
              priority: Priority.high,
              icon: android.smallIcon,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }
}
