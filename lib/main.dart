import 'package:flutter/material.dart';
import 'package:whoreads/core/router/app_router.dart';
import 'package:whoreads/services/notification/fcm_service.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FcmService.initialize();
  runApp(const WhoReadsApp());
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
