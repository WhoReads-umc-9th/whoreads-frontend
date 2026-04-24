import 'package:flutter/material.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';

import '../../core/network/api_client.dart';
import '../../widgets/auth/common_dialog.dart';

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

    // 로딩 시작, 아이디 사용 가능 여부 초기화
    setState(() {
      _isCheckingId = true;
      _isIdAvailable = null;
    });

    try {
      final response = await ApiClient.dio.post(
        '/auth/check-id',
        data: {"login_id": id},
      );

      // 상태 코드에 따른 분기 처리
      if (response.statusCode == 200) {
        // [200] 사용 가능한 아이디
        setState(() => _isIdAvailable = true);

        if (!mounted) return;
        showCustomDialog(
          context,
          title: '사용 가능한 아이디입니다',
          content: '현재 아이디를 사용하시겠습니까?',
        );
      }
      else if (response.statusCode == 409) {
        // [409] 이미 존재하는 아이디 (중복)
        setState(() => _isIdAvailable = false);

        if (!mounted) return;
        showCustomDialog(
          context,
          title: '사용할 수 없는 아이디입니다',
          content: '이미 사용 중인 아이디입니다.\n다른 아이디를 입력해주세요.',
        );
      }
      else if (response.statusCode == 401) {
        // [401] 인증 실패
        setState(() => _isIdAvailable = false);

        if (!mounted) return;
        showCustomDialog(
          context,
          title: '인증 실패',
          content: '권한이 없거나 인증에 실패했습니다.',
        );
      }
      else if (response.statusCode == 500) {
        // [500] 서버 오류
        setState(() => _isIdAvailable = false);

        if (!mounted) return;
        showCustomDialog(
          context,
          title: '서버 오류',
          content: '서버 통신 중 문제가 발생했습니다.\n관리자에게 문의해주세요.',
        );
      }
      else {
        // [기타] 알 수 없는 오류
        setState(() => _isIdAvailable = false);

        if (!mounted) return;
        showCustomDialog(
          context,
          title: '오류 발생',
          content: '알 수 없는 오류가 발생했습니다.\n(코드: ${response.statusCode})',
        );
      }
    } catch (e) {
      // [네트워크 오류 등]
      setState(() => _isIdAvailable = false);

      if (!mounted) return;
      showCustomDialog(
        context,
        title: '통신 오류',
        content: '서버와 연결할 수 없습니다.\n인터넷 연결을 확인해주세요.',
      );
    } finally {
      // 로딩 종료
      if (mounted) {
        setState(() {
          _isCheckingId = false;
        });
      }
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
      // [삭제] 기존 bottomNavigationBar 코드 제거됨

      body: SafeArea(
        child: SingleChildScrollView( // 키보드가 올라왔을 때 스크롤 가능하도록 감싸는 것 추천
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

              /// ✅ 아이디 입력 섹션 (기존 코드 유지)
              const Text('아이디', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelColor)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idCtrl,
                      onChanged: (text) {
                        setState(() { _isIdAvailable = null; });
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        suffixIconConstraints: const BoxConstraints(minHeight: 24),

                        hintText: '아이디 입력',
                        hintStyle: TextStyle(color: hintColor),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isCheckingId ? null : _checkIdDuplicate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      disabledBackgroundColor: Colors.grey[400],
                    ),
                    child: _isCheckingId
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('중복확인', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// ✅ 비밀번호 입력 섹션 (기존 코드 유지)
              const Text('비밀번호', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _pwCtrl,
                obscureText: _obscurePw,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIconConstraints: const BoxConstraints(minHeight: 24),

                  hintText: '영문, 숫자 8자리 이상 입력',
                  hintStyle: const TextStyle(color: hintColor),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _obscurePw = !_obscurePw),
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.all(4),
                          child: Icon(_obscurePw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFFBDBDBD), size: 22),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _clearPassword,
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.cancel_outlined, color: Color(0xFFBDBDBD), size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40), // [간격 추가] 비밀번호 입력란과 가입버튼 사이

              /// ✅ [위치 이동] 가입하기 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _canSignup ? _onTapSignup : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _canSignup ? Colors.black : const Color(0xFFE5E7EB),
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
                      color: _canSignup ? Colors.white : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20), // 하단 여백 확보
            ],
          ),
        ),
      ),
    );
  }
}
