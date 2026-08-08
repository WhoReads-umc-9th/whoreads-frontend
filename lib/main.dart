import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:whoreads/core/router/app_router.dart';
import 'package:whoreads/services/notification/fcm_service.dart';
import 'package:whoreads/services/timer/foreground_service_manager.dart';
import 'package:whoreads/services/timer/timer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env 파일 안전하게 로드
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env load skipped or failed on web: $e');
  }

  // 2. 카카오 SDK 초기화 (웹일 때는 JavaScript App Key 우선 적용)
  try {
    final nativeKey = dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '';
    final jsKey = dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? nativeKey;

    KakaoSdk.init(
      nativeAppKey: nativeKey,
      javaScriptAppKey: kIsWeb ? jsKey : null,
    );
  } catch (e) {
    debugPrint('KakaoSdk init skipped or failed: $e');
  }

  // 3. Firebase 및 FCM 안전 초기화
  try {
    final isFirebaseReady = await _initializeFirebaseSafely();
    if (isFirebaseReady && _supportsFcmNotifications()) {
      await FcmService.initialize();
    }
  } catch (e) {
    debugPrint('Firebase/FCM setup skipped: $e');
  }

  // 4. 모바일(Android) 전용 포그라운드 서비스
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      ForegroundServiceManager().initService();
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    } catch (e) {
      debugPrint('ForegroundTask setup skipped: $e');
    }
  }

  // 5. 무조건 앱 실행
  runApp(const WhoReadsApp());
}

void _onReceiveTaskData(dynamic data) {
  if (data is Map && data['type'] == 'notification_pressed') {
    AppRouter.navigateAndRemoveUntil('/timer');
    return;
  }
  TimerService().handleForegroundData(data);
}

Future<bool> _initializeFirebaseSafely() async {
  // 웹 환경일 경우 Firebase.initializeApp() 옵션 미비로 인한 어설션 에러 차단
  if (kIsWeb) {
    debugPrint('Firebase initialization skipped on Web.');
    return false;
  }

  try {
    await Firebase.initializeApp();
    return true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    return false;
  }
}

bool _supportsFcmNotifications() {
  if (kIsWeb) return false;

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

class WhoReadsApp extends StatelessWidget {
  const WhoReadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.generateRoute,
      navigatorKey: AppRouter.navigatorKey,
      initialRoute: '/',
    );
  }
}