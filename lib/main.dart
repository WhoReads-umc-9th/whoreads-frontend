import 'package:flutter/material.dart';
import 'package:whoreads/core/router/app_router.dart';
import 'package:whoreads/services/notification/fcm_service.dart';
import 'package:whoreads/services/timer/foreground_service_manager.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isFirebaseReady = await _initializeFirebaseSafely();
  if (isFirebaseReady && _supportsFcmNotifications()) {
    await FcmService.initialize();
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    await ForegroundServiceManager().init();
  }
    runApp(const WhoReadsApp());
}

Future<bool> _initializeFirebaseSafely() async {
  try {
    await Firebase.initializeApp();
    return true;
  } on FirebaseException catch (e) {
    debugPrint('Firebase initialization skipped: ${e.message ?? e.code}');
    return false;
  }
}

bool _supportsFcmNotifications() {
  if (kIsWeb) {
    return false;
  }

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
      home: const SplashScreen(),
      onGenerateRoute: AppRouter.generateRoute,
      navigatorKey: AppRouter.navigatorKey,
    );
  }
}
