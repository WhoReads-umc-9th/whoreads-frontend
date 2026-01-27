import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
          // 1️⃣ 약관 시트 닫기
          Navigator.of(context).pop();

          // 2️⃣ 회원가입 페이지로 이동
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SignupPage()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    /// 🔧 여기 값만 조절하면 하단 레이아웃이 바뀝니다
    const double indicatorButtonGap = 44;
    const double bottomPadding = 32;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              /// 1️⃣ 상단 고정 영역 – 둘러보기
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

              /// 2️⃣ 중단 – 온보딩 PageView
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

              /// 3️⃣ 하단 고정 – 인디케이터 + 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  bottomPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// 페이지 인디케이터
                    DotIndicator(
                      count: onboardingPages.length,
                      activeIndex: _index,
                    ),

                    const SizedBox(height: indicatorButtonGap),

                    /// 로그인 / 회원가입 버튼
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

                    /// 계정 찾기
                    TextButton(
                      onPressed: () {
                        // TODO: 계정 찾기 화면으로 이동
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
