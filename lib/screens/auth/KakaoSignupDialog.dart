import 'package:flutter/material.dart';

import '../../services/kakao_auth_service.dart';

/// 카카오 신규 회원 추가 정보 입력 다이얼로그.
/// 이메일 회원가입의 [SignupOverlayDialog] 와 동일한 UI지만
/// 카카오 registrationToken 으로 /auth/kakao/signup 을 호출한다.
class KakaoSignupDialog extends StatefulWidget {
  final String registrationToken;
  final String? initialNickname;

  const KakaoSignupDialog({
    super.key,
    required this.registrationToken,
    this.initialNickname,
  });

  @override
  State<KakaoSignupDialog> createState() => _KakaoSignupDialogState();
}

class _KakaoSignupDialogState extends State<KakaoSignupDialog> {
  final TextEditingController _nicknameCtrl = TextEditingController();
  final KakaoAuthService _kakaoAuthService = KakaoAuthService();

  String? selectedGender;
  String? selectedAge;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialNickname != null && widget.initialNickname!.isNotEmpty) {
      _nicknameCtrl.text = widget.initialNickname!;
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  bool get isValid =>
      _nicknameCtrl.text.isNotEmpty &&
      selectedGender != null &&
      selectedAge != null;

  Future<void> _submitSignup() async {
    setState(() => isLoading = true);

    final error = await _kakaoAuthService.signup(
      registrationToken: widget.registrationToken,
      nickname: _nicknameCtrl.text.trim(),
      gender: selectedGender!,
      ageGroup: selectedAge!,
    );

    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context, _nicknameCtrl.text.trim());
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    '닉네임과 성별, 연령을 입력해주세요',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 28),

                const Text('닉네임', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nicknameCtrl,
                  decoration: InputDecoration(
                    hintText: '예) 홍길동',
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                const Text('성별', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _genderButton('남자', 'MALE'),
                    const SizedBox(width: 12),
                    _genderButton('여자', 'FEMALE'),
                  ],
                ),
                const SizedBox(height: 20),

                const Text('연령', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ageButton('10대', 'TEENAGERS'),
                    const SizedBox(width: 6),
                    _ageButton('20대', 'TWENTIES'),
                    const SizedBox(width: 6),
                    _ageButton('30대', 'THIRTIES'),
                    const SizedBox(width: 6),
                    _ageButton('40대', 'FORTIES'),
                    const SizedBox(width: 6),
                    _ageButton('50대+', 'FIFTY_PLUS'),
                  ],
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isValid && !isLoading ? _submitSignup : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isValid ? const Color(0xFFFF6A00) : const Color(0xFFE0E0E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderButton(String text, String value) {
    final selected = selectedGender == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedGender = value),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF1E8) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFFF6A00) : const Color(0xFFE0E0E0),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? const Color(0xFFFF6A00) : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _ageButton(String text, String value) {
    final selected = selectedAge == value;

    return GestureDetector(
      onTap: () => setState(() => selectedAge = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1E8) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFFF6A00) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? const Color(0xFFFF6A00) : Colors.black87,
          ),
        ),
      ),
    );
  }
}
