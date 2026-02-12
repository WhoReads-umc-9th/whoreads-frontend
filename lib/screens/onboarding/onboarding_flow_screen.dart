import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:whoreads/screens/auth/EmailVerifyPage.dart';

import '../auth/login_page.dart';
import '../auth/signup_page.dart';
import '../../widgets/onboarding/dot_indicator.dart';
import '../../widgets/onboarding/onboarding_page.dart';
import '../../widgets/onboarding/primary_buttons.dart';
import '../../widgets/auth/signup_terms_sheet.dart';
import 'onboarding_data.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    /// 서버 헬스 체크 (UI 로드 이후 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServerHealth();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// ===============================
  /// 서버 Health Check
  /// ===============================
  Future<void> _checkServerHealth() async {
    const String url = 'http://43.201.122.162/api/health';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ 서버 정상: ${response.body}');
      } else {
        debugPrint('⚠️ 서버 오류 응답: ${response.statusCode}');
        _showServerErrorDialog();
      }
    } catch (e) {
      debugPrint('❌ 서버 연결 실패: $e');
      _showServerErrorDialog();
    }
  }

  void _showServerErrorDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('서버 연결 오류'),
        content: const Text(
          '현재 서버에 연결할 수 없습니다.\n'
              '네트워크 상태를 확인하거나 잠시 후 다시 시도해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// UI Logic
  /// ===============================
  void _onSkip() {
    // TODO: 홈/메인 화면으로 이동
  }

  void _openSignupTermsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => SignupTermsSheet(
        onAgreed: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmailVerifyPage()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double indicatorButtonGap = 44;
    const double bottomPadding = 32;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              /// 상단 – 둘러보기
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _onSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '둘러보기',
                      style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        fontFamily: 'Pretendard Variable',
                      ),
                    ),
                  ),
                ),
              ),

              /// 중단 – 온보딩 페이지
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: onboardingPages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    return OnboardingPage(data: onboardingPages[i]);
                  },
                ),
              ),

              /// 하단 – 인디케이터 + 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DotIndicator(
                      count: onboardingPages.length,
                      activeIndex: _index,
                    ),
                    const SizedBox(height: indicatorButtonGap),
                    Row(
                      children: [
                        Expanded(
                          child: OutlineActionButton(
                            label: '로그인',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledActionButton(
                            label: '회원가입',
                            onPressed: _openSignupTermsSheet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        // TODO: 계정 찾기
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '계정이 기억나지 않나요? 계정 찾기',
                        style: TextStyle(
                          color: Color(0xFF767676),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
