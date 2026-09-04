import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../widgets/auth/common_dialog.dart';

/// 계정 찾기 - 본인인증
///
/// 흐름:
/// 1) 이메일 입력 → 인증하기
/// 2) 인증번호(4자리) 입력 → 확인
/// 3) 인증 성공 시 "이미 가입된 계정이 있습니다" + 계정(아이디) 표시
class FindAccountPage extends StatefulWidget {
  const FindAccountPage({super.key});

  @override
  State<FindAccountPage> createState() => _FindAccountPageState();
}

class _FindAccountPageState extends State<FindAccountPage> {
  bool isRequested = false; // 인증번호 발송 여부
  bool isVerified = false; // 인증 완료(결과 화면) 여부
  bool isLoading = false;

  String? selectedDomain;
  String? sentEmail; // 아이디를 발송한 이메일 (결과 화면 표시용)

  Timer? _timer;
  int remainSeconds = 170; // 2:50

  final List<String> _domainList = const [
    'naver.com',
    'gmail.com',
    'hanmail.net',
    'kakao.com',
    'daum.net',
    'nate.com',
  ];

  final TextEditingController _emailIdController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  final FocusNode _codeFocusNode = FocusNode();

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
    final domain = selectedDomain;
    if (id.isEmpty || domain == null || domain.isEmpty) return null;
    return '$id@$domain';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailIdController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  // ================= 이메일 인증번호 발송 =================
  Future<void> _sendEmailCode() async {
    final email = _email;
    if (email == null || isLoading) return;

    setState(() => isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/auth/email/send',
        data: {'email': email},
      );

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

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
        _showError(decoded['message'] ?? '인증 메일 발송에 실패했습니다.');
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

    if (email == null || code.length < 6 || isLoading) return;

    setState(() => isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/auth/email/verify',
        data: {
          'email': email,
          'code': code,
        },
      );

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      bool isActuallySuccess = false;
      if (response.statusCode == 200 && decoded['is_success'] == true) {
        if (decoded.containsKey('result') && decoded['result'] == false) {
          isActuallySuccess = false;
        } else {
          isActuallySuccess = true;
        }
      }

      if (isActuallySuccess) {
        _timer?.cancel();
        if (!mounted) return;
        FocusScope.of(context).unfocus();
        // 인증 완료 → 아이디 찾기 API 호출 (가입된 이메일로 아이디 발송)
        await _findLoginId();
      } else {
        if (!mounted) return;
        showCustomDialog(
          context,
          title: '인증번호가 올바르지 않습니다',
          content: '인증번호를 다시 입력해주세요.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showCustomDialog(
        context,
        title: '통신 오류',
        content: '서버와 연결할 수 없습니다.\n잠시 후 다시 시도해주세요.',
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= 아이디 찾기 (이메일로 아이디 발송) =================
  Future<void> _findLoginId() async {
    final email = _email;
    if (email == null) return;

    try {
      final response = await ApiClient.dio.post(
        '/auth/find-id',
        data: {'email': email},
      );

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (response.statusCode == 200 &&
          !(decoded is Map && decoded['is_success'] == false)) {
        if (!mounted) return;
        setState(() {
          isVerified = true;
          sentEmail = email;
        });
      } else if (response.statusCode == 404) {
        if (!mounted) return;
        showCustomDialog(
          context,
          title: '가입된 계정이 없습니다',
          content: '입력하신 이메일로 가입된 계정을 찾을 수 없습니다.',
        );
      } else {
        final message = decoded is Map ? decoded['message']?.toString() : null;
        _showError(message ?? '아이디 발송에 실패했습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      showCustomDialog(
        context,
        title: '통신 오류',
        content: '서버와 연결할 수 없습니다.\n잠시 후 다시 시도해주세요.',
      );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: isVerified ? _buildResult() : _buildForm(),
      ),
    );
  }

  // ================= 결과 화면 =================
  Widget _buildResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          '이메일로 아이디를\n보내드렸어요',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          '아래 이메일로 로그인 아이디를 발송했습니다.\n메일함을 확인해주세요.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Icon(
              Icons.mail_outline,
              size: 22,
              color: Color(0xFF9E9E9E),
            ),
            const SizedBox(width: 12),
            Text(
              sentEmail ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================= 입력 화면 =================
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          '본인확인을 위해\n이메일을 입력하세요',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 36),

        /// [1] 이메일 입력 Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _emailIdController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '이메일 입력',
                  hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return PopupMenuButton<String>(
                    constraints:
                        BoxConstraints.tightFor(width: constraints.maxWidth),
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 4,
                    color: Colors.white,
                    onSelected: (String value) {
                      setState(() => selectedDomain = value);
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
                        border: Border(bottom: BorderSide(color: Colors.grey)),
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
                          const Icon(Icons.keyboard_arrow_down,
                              size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed:
                  (_email != null && !isLoading) ? _sendEmailCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFFBDBDBD),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

        /// [2] 인증번호 입력란 + 확인 버튼
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
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: '6자리 숫자 입력',
                    hintStyle:
                        TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
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

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_codeController.text.length >= 6 && !isLoading)
                  ? _verifyCode
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '확인',
                style: TextStyle(
                  fontSize: 16,
                  color: _codeController.text.length >= 6
                      ? Colors.white
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
