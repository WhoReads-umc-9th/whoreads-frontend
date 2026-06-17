import 'package:flutter/material.dart';
import 'package:whoreads/screens/celebrities/celebrities_book_page.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';
import 'package:whoreads/screens/splash_screen.dart';
import 'package:whoreads/screens/timer/timer_default_screen.dart';
import 'package:whoreads/services/auth_service.dart';

class AppRouter {
  AppRouter._internal();
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  static Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState?.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  static Future<dynamic>? navigateAndRemoveUntil(
      String routeName, {
        Object? arguments,
      }) {
    return navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName,
          (route) => false,
      arguments: arguments,
    );
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => FutureBuilder<bool>(
            future: AuthService().getLoggedIn(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasData) {
                final bool isLoggedIn = snapshot.data ?? false;

                return isLoggedIn ? const MyLibraryPage() : const SplashScreen();
              }

              return const Scaffold(
                body: Center(child: Text('인증 에러가 발생했습니다.')),
              );
            },
          ),
        );

      case '/celebrity/book':
        final args = settings.arguments;
        if (args == null) return _errorRoute(settings.name);

        final int celebId = args is int
            ? args
            : int.tryParse(args.toString()) ?? 0;
        return MaterialPageRoute(
          builder: (_) => CelebritiesBookPage(celebrityId: celebId),
        );

      case '/timer':
        return MaterialPageRoute(builder: (_) => const TimerPage());

      case '/library':
        return MaterialPageRoute(builder: (_) => const MyLibraryPage());

      default:
        return _errorRoute(settings.name);
    }
  }

  static Route<dynamic> _errorRoute(String? name) {
    return MaterialPageRoute(
      builder: (_) =>
          Scaffold(body: Center(child: Text('No route defined for $name'))),
    );
  }
}