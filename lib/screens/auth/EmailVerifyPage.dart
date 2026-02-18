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

  final List<String> _domainList = [
    'naver.com',
    'gmail.com',
    'hanmail.net',
    'kakao.com',
    'daum.net',
    'nate.com',
    '직접입력',
  ];

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

            /// [1] 이메일 입력 Row (기존 코드 유지)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _emailIdController,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('@', style: TextStyle(fontSize: 16)),
                ),
                Expanded(
                  flex: 4,
                  child: isCustomDomain
                      ? Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextField(
                        controller: _domainController,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black, height: 1.2),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.fromLTRB(
                              0, 0, 30, 8),
                          hintText: '직접입력',
                          hintStyle: const TextStyle(fontSize: 14, color: Colors
                              .grey),
                          border: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey)),
                          enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey)),
                          focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black)),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isCustomDomain = false;
                              selectedDomain = null;
                              _domainController.clear();
                            });
                          },
                          child: const Icon(Icons.close, size: 18, color: Colors
                              .grey),
                        ),
                      ),
                    ],
                  )
                      : LayoutBuilder(
                    builder: (context, constraints) {
                      return PopupMenuButton<String>(
                        constraints: BoxConstraints.tightFor(width: constraints
                            .maxWidth),
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(8)),
                        elevation: 4,
                        color: Colors.white,
                        onSelected: (String value) {
                          if (value == '직접입력') {
                            setState(() {
                              isCustomDomain = true;
                              selectedDomain = null;
                            });
                          } else {
                            setState(() {
                              selectedDomain = value;
                              isCustomDomain = false;
                            });
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return _domainList.map((String choice) {
                            return PopupMenuItem<String>(
                              value: choice,
                              height: 40,
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(choice,
                                    style: const TextStyle(fontSize: 14)),
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          height: 36,
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: Colors.grey)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDomain ?? '선택',
                                style: TextStyle(
                                  color: selectedDomain == null
                                      ? Colors.grey
                                      : Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 20,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isLoading ? null : _sendEmailCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(
                    isRequested ? '재전송' : '인증하기',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),

            /// [2] 인증번호 입력란 + 확인 버튼 (조건부 렌더링)
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

              const SizedBox(height: 40), // [위치 조정] 입력란과 확인 버튼 사이 간격

              // --- 확인 버튼 (여기로 이동) ---
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _codeController.text.length >= 4 && !isLoading
                      ? _verifyCode
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],

            // 기존의 Spacer()와 하단 버튼 코드는 삭제됨
          ],
        ),
      ),
    );
  }
}