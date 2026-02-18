import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart'; // flutter_svg 패키지 import

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

    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingFlowScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 배경이 흰색이므로 상태바 아이콘(배터리, 시간 등)은 검은색(dark)으로 설정
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white, // 배경색 흰색으로 변경
        body: Center(
          child: SvgPicture.asset(
            'assets/images/logo.svg', // 로고 경로
            width: 200, // 로고 크기 조절 (필요에 따라 숫자 변경)
          ),
        ),
      ),
    );
  }
}