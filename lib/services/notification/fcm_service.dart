import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

import 'package:whoreads/core/router/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서도 Firebase 초기화 필요
  await Firebase.initializeApp();
  debugPrint("📬 백그라운드 메시지 수신: ${message.messageId}");
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // 1. 안드로이드 전용 알림 채널 정의 (Static하게 관리)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // 백엔드에서 전송 시 channel_id와 일치해야 함
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
    bool isAuthorized = await requestNotificationPermission();
    if (!isAuthorized) return;

    try {
      String? token = await _messaging.getToken();
      if (token == null) return;

      debugPrint("🚀 FCM Token 발급: $token");

      await ApiClient.dio.post(
        "/members/me/fcm-tokens", // 백엔드 API 엔드포인트
        data: {'fcm_token': token},
      );

      debugPrint("✅ 서버에 토큰 저장 성공");

      _messaging.onTokenRefresh.listen((newToken) async {
        await ApiClient.dio.post(
          "/members/me/fcm-tokens",
          data: {'fcm_token': newToken},
        );
      });
    } catch (e) {
      debugPrint("⚠️ FCM 전송 에러: $e");
    }
  }

  static Future<void> _handleDeepLink(String type, dynamic linkData) async {
    final String? celebrityId = linkData['celebrity_id']?.toString();

    debugPrint("딥링크 데이터: type=$type, celebrityId=$celebrityId");

    if (type == 'FOLLOW' && celebrityId != null) {
      debugPrint("FOLLOW 딥링크 탐지: 셀럽 책 화면으로 이동");
      AppRouter.navigateTo('/celebrity/book', arguments: celebrityId);
    } else if (type == 'ROUTINE') {
      debugPrint("ROUTINE 딥링크 탐지: 타이머 화면으로 고고");
      AppRouter.navigateTo('/timer');
    } else {
      debugPrint("⚠️ 알 수 없는 딥링크 타입: $type");
    }
  }

  static Future<void> _setupForegroundNotifications() async {
    // 1. 안드로이드 알림 채널 생성 (OS 등록)
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
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          debugPrint("🔔 알림 클릭됨: ${details.payload}");
          try {
            // 1. JSON 문자열을 Map으로 변환
            final Map<String, dynamic> data = jsonDecode(details.payload!);

            // 2. 💡 대괄호 문법(['key'])으로 접근해야 에러가 안 납니다.
            final String? type = data['type'];

            // 백엔드에서 'link'라는 key 안에 데이터가 있는지 확인 필요
            // 만약 평평한 구조라면 data['celebrity_id'] 이런 식으로 바로 접근하세요.
            final dynamic link = data['link'] ?? data;

            debugPrint("✅ 파싱 성공: type=$type, link=$link");
            _handleDeepLink(type ?? '', link ?? {});
          } catch (e) {
            debugPrint("❌ 클릭 데이터 처리 에러: $e");
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

      // notification 객체가 있을 때만 로컬 알림을 띄움
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
