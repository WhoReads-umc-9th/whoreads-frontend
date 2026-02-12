import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _isLoading = false;

  static const String _baseUrl = 'http://43.201.122.162';

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  bool get _canLogin {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    return !_isLoading && id.isNotEmpty && pw.length >= 8;
  }

  /// ===============================
  /// 로그인 API
  /// ===============================
  Future<void> _onTapLogin() async {
    if (!_canLogin) return;

    final loginId = _idCtrl.text.trim();
    final password = _pwCtrl.text;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'login_id': loginId,
          'password': password,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['is_success'] == true) {
        final result = decoded['result'];

        final accessToken = result['access_token'];
        final refreshToken = result['refresh_token'];

        debugPrint('✅ 로그인 성공');
        debugPrint('accessToken: $accessToken');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 성공')),
        );

        // TODO:
        // 1. accessToken / refreshToken secure storage 저장
        // 2. 메인 화면 이동

      } else {
        _showError(decoded['message'] ?? '로그인에 실패했습니다.');
      }
    } catch (e) {
      _showError('서버와 통신할 수 없습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onTapResetPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호 재설정 클릭')),
    );
  }

  void _clearPassword() {
    if (_pwCtrl.text.isEmpty) return;
    _pwCtrl.clear();
    setState(() {});
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
                backgroundColor:
                _canLogin ? Colors.black : const Color(0xFFE5E7EB),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                '로그인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _canLogin
                      ? Colors.white
                      : const Color(0xFF9CA3AF),
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
                '아이디와 비밀번호를\n입력하세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 32),

              /// 아이디
              const Text(
                '아이디',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _idCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '아이디 입력',
                  hintStyle: TextStyle(color: hintColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// 비밀번호
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
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () =>
                            setState(() => _obscurePw = !_obscurePw),
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
                      ),
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
