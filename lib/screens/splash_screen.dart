import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import 'my_library/my_library_page.dart';
import 'onboarding/onboarding_flow_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _moveNextPage();
  }

  Future<void> _moveNextPage() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      final accessToken = await TokenStorage.getAccessToken();

      debugPrint('====================');
      debugPrint('TOKEN = $accessToken');
      debugPrint('====================');

      if (!mounted) return;

      // 토큰 없음 -> 온보딩
      if (accessToken == null || accessToken.isEmpty) {
        _goToOnboarding();
        return;
      }

      // 토큰 검증
      final response = await ApiClient.dio.get('/members/me');

      debugPrint('USER CHECK: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        _goToHome();
      } else {
        await TokenStorage.clear();
        _goToOnboarding();
      }
    } catch (e) {
      debugPrint('AUTO LOGIN FAILED: $e');

      // 인증 실패 시 저장된 토큰 제거
      await TokenStorage.clear();

      if (!mounted) return;

      _goToOnboarding();
    }
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MyLibraryPage(),
      ),
          (route) => false,
    );
  }

  void _goToOnboarding() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingFlowScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SvgPicture.asset(
            'assets/images/logo.svg',
            width: 200,
          ),
        ),
      ),
    );
  }
}