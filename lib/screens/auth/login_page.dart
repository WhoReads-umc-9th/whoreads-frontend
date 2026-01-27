import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailIdCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _obscurePw = true;

  final List<String> _domains = const [
    'naver.com',
    'gmail.com',
    'hanmail.net',
    'kakao.com',
    'daum.net',
    'net.com',
  ];

  static const String _customDomainValue = '__CUSTOM__';
  String? _selectedDomain;
  final _customDomainCtrl = TextEditingController();

  @override
  void dispose() {
    _emailIdCtrl.dispose();
    _pwCtrl.dispose();
    _customDomainCtrl.dispose();
    super.dispose();
  }

  bool get _isCustomDomain => _selectedDomain == _customDomainValue;

  String? get _domainValue {
    if (_selectedDomain == null) return null;
    if (_isCustomDomain) {
      final v = _customDomainCtrl.text.trim();
      return v.isEmpty ? null : v;
    }
    return _selectedDomain;
  }

  bool get _canLogin {
    final emailId = _emailIdCtrl.text.trim();
    final domain = _domainValue;
    final pw = _pwCtrl.text;
    return emailId.isNotEmpty && domain != null && pw.length >= 8;
  }

  void _onTapResetPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호 재설정 클릭')),
    );
  }

  void _onTapLogin() {
    final email = '${_emailIdCtrl.text.trim()}@${_domainValue!}';
    final pw = _pwCtrl.text;

    // TODO: 로그인 API 연동
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('로그인 시도: $email (pw length: ${pw.length})')),
    );
  }

  void _clearPassword() {
    if (_pwCtrl.text.isEmpty) return;
    _pwCtrl.clear();
    setState(() {}); // ✅ 아이콘/버튼 활성화 상태 갱신
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E7EB);
    const hintColor = Color(0xFFBDBDBD);
    const labelColor = Color(0xFF9E9E9E);

    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            math.max(16, viewInsetsBottom + 12),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _canLogin ? _onTapLogin : null,
              style: FilledButton.styleFrom(
                backgroundColor: _canLogin ? Colors.black : const Color(0xFFE5E7EB),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                '로그인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _canLogin ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                '이메일과 비밀번호를\n입력하세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                '이메일',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _emailIdCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '이메일 입력',
                        hintStyle: TextStyle(color: hintColor),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '@',
                    style: TextStyle(
                      fontSize: 16,
                      color: hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    flex: 6,
                    child: _isCustomDomain
                        ? TextField(
                      controller: _customDomainCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '직접입력',
                        hintStyle: const TextStyle(color: hintColor),
                        suffixIcon: IconButton(
                          tooltip: '도메인 선택으로 변경',
                          onPressed: () {
                            setState(() {
                              _customDomainCtrl.clear();
                              _selectedDomain = null;
                            });
                          },
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                    )
                        : DropdownButtonFormField<String>(
                      value: _selectedDomain,
                      onChanged: (v) {
                        setState(() {
                          _selectedDomain = v;
                          if (v != _customDomainValue) {
                            _customDomainCtrl.clear();
                          }
                        });
                      },
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '선택',
                        hintStyle: TextStyle(color: hintColor),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      items: [
                        ..._domains.map(
                              (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: _customDomainValue,
                          child: Text('직접입력'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                '비밀번호',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _pwCtrl,
                obscureText: _obscurePw,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '영문, 숫자 8자리 이상 입력',
                  hintStyle: const TextStyle(color: hintColor),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),

                  /// ✅ 눈 + X(전체삭제)
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _obscurePw = !_obscurePw),
                        icon: Icon(
                          _obscurePw
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFFBDBDBD),
                        ),
                      ),
                      IconButton(
                        onPressed: _clearPassword,
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: Color(0xFFBDBDBD),
                        ),
                      )
                    ],
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 96,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      '비밀번호를 잊으셨나요? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: _onTapResetPassword,
                      child: const Text(
                        '비밀번호 재설정',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
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