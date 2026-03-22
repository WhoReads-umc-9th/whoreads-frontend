import 'package:flutter/material.dart';
import 'package:whoreads/screens/celebrities/celebrities_book_page.dart';
import 'package:whoreads/screens/auth/login_page.dart';
import 'package:whoreads/screens/timer/timer_default_screen.dart';

class AppRouter {
  // 💡 싱글톤 패턴: 내부 생성자를 private으로 선언
  AppRouter._internal();

  // 💡 전역에서 사용할 단 하나의 NavigatorKey
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // 💡 [추가] 어디서든 context 없이 이동할 수 있는 함수 (Controller의 redirect 역할)
  static Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState?.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  // 💡 [추가] 현재 스택을 다 날리고 이동 (로그아웃 등 세션 만료 시 사용)
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
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case '/celebrity/book':
        final args = settings.arguments;
        // Null 방어 로직 추가
        if (args == null) return _errorRoute(settings.name);

        final int celebId = args is int
            ? args
            : int.tryParse(args.toString()) ?? 0;
        return MaterialPageRoute(
          builder: (_) => CelebritiesBookPage(celebrityId: celebId),
        );

      case '/timer':
        return MaterialPageRoute(builder: (_) => const TimerPage());

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
