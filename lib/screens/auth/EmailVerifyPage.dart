import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'signup_page.dart';

class EmailVerifyPage extends StatefulWidget {
  const EmailVerifyPage({super.key});

  @override
  State<EmailVerifyPage> createState() => _EmailVerifyPageState();
}

class _EmailVerifyPageState extends State<EmailVerifyPage> {
  bool isRequested = false;
  bool isCustomDomain = false;
  bool isLoading = false;

  String? selectedDomain;

  Timer? _timer;
  int remainSeconds = 170;

  final TextEditingController _emailIdController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  final FocusNode _codeFocusNode = FocusNode();

  static const String _baseUrl = 'http://43.201.122.162';

  // ================= Timer =================
  void _startTimer() {
    _timer?.cancel();
    remainSeconds = 170;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainSeconds <= 0) {
        timer.cancel();
      } else {
        setState(() => remainSeconds--);
      }
    });
  }

  String get timerText {
    final min = remainSeconds ~/ 60;
    final sec = remainSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String? get _email {
    final id = _emailIdController.text.trim();
    final domain = isCustomDomain
        ? _domainController.text.trim()
        : selectedDomain;

    if (id.isEmpty || domain == null || domain.isEmpty) return null;
    return '$id@$domain';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailIdController.dispose();
    _domainController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  // ================= 이메일 인증 요청 =================
  Future<void> _sendEmailCode() async {
    final email = _email;
    if (email == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['is_success'] == true) {
        setState(() {
          isRequested = true;
          _codeController.clear();
        });

        _startTimer();

        Future.delayed(const Duration(milliseconds: 100), () {
          _codeFocusNode.requestFocus();
        });
      } else {
        _showError(decoded['message'] ?? '인증 메일 발송 실패');
      }
    } catch (e) {
      _showError('서버와 통신할 수 없습니다.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= 인증번호 확인 =================
  Future<void> _verifyCode() async {
    final email = _email;
    final code = _codeController.text.trim();

    if (email == null || code.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/email/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['is_success'] == true) {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SignupPage(email: email),
          ),
        );
      } else {
        _showError(decoded['message'] ?? '인증번호가 올바르지 않습니다.');
      }
    } catch (e) {
      _showError('서버와 통신할 수 없습니다.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              '본인확인을 위해\n이메일을 입력하세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 36),

            /// 이메일 입력
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailIdController,
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('@'),
                ),
                Expanded(
                  child: isCustomDomain
                      ? TextField(
                    controller: _domainController,
                    decoration: const InputDecoration(
                      hintText: '직접입력',
                      border: UnderlineInputBorder(),
                    ),
                  )
                      : DropdownButtonFormField<String>(
                    value: selectedDomain,
                    hint: const Text('선택'),
                    items: const [
                      'naver.com',
                      'gmail.com',
                      'hanmail.net',
                      'kakao.com',
                      'daum.net',
                      'nate.com',
                      '직접입력',
                    ].map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text(d),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == '직접입력') {
                        setState(() {
                          isCustomDomain = true;
                          selectedDomain = null;
                        });
                      } else {
                        setState(() => selectedDomain = value);
                      }
                    },
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                /// 인증 버튼
                ElevatedButton(
                  onPressed: isLoading ? null : _sendEmailCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isRequested ? '재전송' : '인증하기',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

            /// 인증번호 입력
            if (isRequested) ...[
              const SizedBox(height: 28),
              const Text(
                '인증번호',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timerText,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),

            /// 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                _codeController.text.length >= 4 && !isLoading
                    ? _verifyCode
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
