import 'package:flutter/material.dart';

/// 로그인 방법 선택 바텀시트
///
/// - 카카오로 로그인
/// - 이메일로 로그인 (→ LoginPage 이동)
class LoginMethodSheet extends StatelessWidget {
  final VoidCallback onKakaoLogin;
  final VoidCallback onEmailLogin;
  final VoidCallback? onFindAccount;

  const LoginMethodSheet({
    super.key,
    required this.onKakaoLogin,
    required this.onEmailLogin,
    this.onFindAccount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            const Text(
              '로그인 방법 선택',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 20),

            // 카카오로 로그인
            _LoginMethodButton(
              onPressed: onKakaoLogin,
              backgroundColor: const Color(0xFFFEE500),
              borderColor: const Color(0xFFFEE500),
              leading: Image.asset(
                'assets/images/basic/kakao.png',
                width: 20,
                height: 20,
              ),
              label: '카카오로 로그인',
              textColor: const Color(0xFF3C1E1E),
            ),

            const SizedBox(height: 12),

            // 이메일로 로그인
            _LoginMethodButton(
              onPressed: onEmailLogin,
              backgroundColor: Colors.white,
              borderColor: const Color(0xFFE5E7EB),
              leading: const Icon(
                Icons.mail_outline,
                color: Color(0xFF1C1C22),
                size: 20,
              ),
              label: '이메일로 로그인',
              textColor: const Color(0xFF1C1C22),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// 로고/아이콘은 왼쪽 정렬, 라벨은 가운데 정렬되는 로그인 방법 버튼
class _LoginMethodButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Widget leading;
  final String label;
  final Color textColor;

  const _LoginMethodButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.leading,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 로고/아이콘 – 왼쪽 정렬 + 간격
                Positioned(
                  left: 16,
                  child: leading,
                ),
                // 라벨 – 가운데 정렬
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
