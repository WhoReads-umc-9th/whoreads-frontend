import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:whoreads/screens/my_library/my_library_page.dart';

class SignupPage extends StatefulWidget {
  final String email;

  const SignupPage({super.key, required this.email});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _isCheckingId = false;
  bool? _isIdAvailable; // null = 아직 확인 안함

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  bool get _canSignup {
    return _idCtrl.text.trim().isNotEmpty &&
        _pwCtrl.text.length >= 8 &&
        _isIdAvailable == true;
  }

  /// 🔥 아이디 중복확인 API
  Future<void> _checkIdDuplicate() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _isCheckingId = true;
      _isIdAvailable = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://43.201.122.162/api/auth/check-id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "login_id": id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final isSuccess = data["is_success"] ?? false;

        setState(() {
          _isIdAvailable = isSuccess;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSuccess ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('아이디 확인 실패')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 오류 발생')),
      );
    } finally {
      setState(() {
        _isCheckingId = false;
      });
    }
  }

  void _clearPassword() {
    if (_pwCtrl.text.isEmpty) return;
    _pwCtrl.clear();
    setState(() {});
  }

  void _onTapSignup() {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MyLibraryPage(
          email: widget.email,
          loginId: id,
          password: pw,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E7EB);
    const hintColor = Color(0xFFBDBDBD);
    const labelColor = Color(0xFF9E9E9E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _canSignup ? _onTapSignup : null,
              style: FilledButton.styleFrom(
                backgroundColor:
                _canSignup ? Colors.black : const Color(0xFFE5E7EB),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                '가입하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color:
                  _canSignup ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '아이디와 비밀번호를\n입력하세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 32),

              /// ✅ 아이디
              const Text(
                '아이디',
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
                    child: TextField(
                      controller: _idCtrl,
                      onChanged: (_) {
                        setState(() {
                          _isIdAvailable = null; // 아이디 바꾸면 다시 확인 필요
                        });
                      },
                      decoration: const InputDecoration(
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
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed:
                      _isCheckingId ? null : _checkIdDuplicate,
                      child: _isCheckingId
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Text('중복확인'),
                    ),
                  ),
                ],
              ),

              if (_isIdAvailable != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _isIdAvailable == true
                        ? '사용 가능한 아이디입니다.'
                        : '이미 사용 중인 아이디입니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isIdAvailable == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              /// ✅ 비밀번호
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
                        onPressed: () => setState(
                                () => _obscurePw = !_obscurePw),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
