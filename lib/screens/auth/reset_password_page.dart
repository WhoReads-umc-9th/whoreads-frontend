import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../widgets/auth/common_dialog.dart';
import 'login_page.dart';

/// 비밀번호 재설정
///
/// 흐름 (첨부 디자인 기준):
/// 1) 이메일 입력 → 인증하기(/재전송)
/// 2) 인증번호(4자리) 입력 → 확인
/// 3) 새 비밀번호 + 재입력 → 비밀번호 재설정 → 이메일 로그인 화면으로 이동
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  bool isRequested = false; // 인증번호 발송 여부
  bool isVerified = false; // 인증 완료 → 새 비밀번호 화면 전환
  bool isLoading = false;

  String? selectedDomain;

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
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();

  final FocusNode _codeFocusNode = FocusNode();

  bool _obscurePw = true;
  bool _obscurePwConfirm = true;

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

  /// 영문 + 숫자 포함, 공백 없이 8자 이상 (서버 정책과 동일)
  bool _isValidPassword(String pw) {
    return RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=\S+$).{8,}$').hasMatch(pw);
  }

  bool get _canReset =>
      _isValidPassword(_pwController.text) &&
      _pwController.text == _pwConfirmController.text;

  @override
  void dispose() {
    _timer?.cancel();
    _emailIdController.dispose();
    _codeController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
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

    if (email == null || code.length < 4 || isLoading) return;

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
        setState(() => isVerified = true);
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

  // ================= 비밀번호 재설정 =================
  Future<void> _resetPassword() async {
    if (!_canReset || isLoading) return;

    setState(() => isLoading = true);

    try {
      final response = await ApiClient.dio.patch(
        '/auth/password',
        data: {
          'newPassword': _pwController.text,
          'confirmPassword': _pwConfirmController.text,
        },
      );

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      final bool ok = response.statusCode == 200 &&
          !(decoded is Map && decoded['is_success'] == false);

      if (!mounted) return;

      if (ok) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Text(
              '비밀번호가 재설정되었습니다.\n다시 로그인해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // 이메일 로그인 화면으로 이동
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('확인', style: TextStyle(color: Color(0xFF1C1C22), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      } else {
        final message = decoded is Map ? decoded['message']?.toString() : null;
        _showError(message ?? '비밀번호 재설정에 실패했습니다.');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: isVerified ? _buildNewPasswordForm() : _buildEmailForm(),
      ),
    );
  }

  // ================= 1~2단계: 이메일 + 인증번호 =================
  Widget _buildEmailForm() {
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
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
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
                    constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            child: Text(choice, style: const TextStyle(fontSize: 14)),
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
                              color: selectedDomain == null ? Colors.grey : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (_email != null && !isLoading) ? _sendEmailCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFFBDBDBD),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
          const Text('인증번호', style: TextStyle(fontSize: 14, color: Colors.grey)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: '4자리 숫자 입력',
                    hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timerText,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_codeController.text.length >= 4 && !isLoading) ? _verifyCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                '확인',
                style: TextStyle(
                  fontSize: 16,
                  color: _codeController.text.length >= 4 ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ================= 3단계: 새 비밀번호 =================
  Widget _buildNewPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          '새로운 비밀번호를\n설정하세요',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 36),

        const Text('새 비밀번호', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        _passwordField(
          controller: _pwController,
          obscure: _obscurePw,
          onToggle: () => setState(() => _obscurePw = !_obscurePw),
        ),

        const SizedBox(height: 24),

        const Text('새 비밀번호 재입력', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        _passwordField(
          controller: _pwConfirmController,
          obscure: _obscurePwConfirm,
          onToggle: () => setState(() => _obscurePwConfirm = !_obscurePwConfirm),
        ),

        // 재입력이 채워졌는데 서로 다르면 안내
        if (_pwConfirmController.text.isNotEmpty &&
            _pwController.text != _pwConfirmController.text) ...[
          const SizedBox(height: 8),
          const Text(
            '비밀번호가 일치하지 않습니다.',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],

        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_canReset && !isLoading) ? _resetPassword : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    '비밀번호 재설정',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _canReset ? Colors.white : const Color(0xFF9CA3AF),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        hintText: '영문, 숫자 8자리 이상 입력',
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
        suffixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 0),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(4),
                child: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFFBDBDBD),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                controller.clear();
                setState(() {});
              },
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.cancel, color: Color(0xFFBDBDBD), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
