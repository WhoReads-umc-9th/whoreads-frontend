import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../services/notification/fcm_service.dart';

class SignupOverlayDialog extends StatefulWidget {
  final String email;
  final String loginId;
  final String password;

  const SignupOverlayDialog({
    super.key,
    required this.email,
    required this.loginId,
    required this.password,
  });

  @override
  State<SignupOverlayDialog> createState() =>
      _SignupOverlayDialogState();
}

class _SignupOverlayDialogState extends State<SignupOverlayDialog> {
  final TextEditingController _nicknameCtrl = TextEditingController();

  String? selectedGender;
  String? selectedAge;
  bool isLoading = false;

  bool get isValid =>
      _nicknameCtrl.text.isNotEmpty &&
          selectedGender != null &&
          selectedAge != null;

  Future<void> _submitSignup() async {
    setState(() => isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/auth/signup',
        data: {
          "request": {
            "login_id": widget.loginId,
            "email": widget.email,
            "password": widget.password,
          },
          "member_info": {
            "nickname": _nicknameCtrl.text,
            "gender": selectedGender,
            "age_group": selectedAge,
          }
        },
      );

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (!mounted) return;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          decoded['is_success'] == true) {
        final result = decoded['result'];
        final accessToken = result['access_token'] as String?;
        final refreshToken = result['refresh_token'] as String?;

        if (accessToken == null) {
          throw Exception('access_token이 응답에 없습니다.');
        }

        await TokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        try {
          await FcmService.sendTokenToServer();
        } catch (e) {
          debugPrint('⚠️ FCM 토큰 전송 실패(회원가입은 유지): $e');
        }

        if (!mounted) return;
        Navigator.pop(context, _nicknameCtrl.text);
      } else {
        final message = decoded['message'] ?? '회원가입에 실패했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.toString())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 28,
          ),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                /// 닉네임 라벨
                const Text(
                  '닉네임',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),

                /// 닉네임 입력
                TextField(
                  controller: _nicknameCtrl,
                  decoration: InputDecoration(
                    hintText: '예) 홍길동',
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 20),

                /// 성별
                const Text(
                  '성별',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _genderButton('남자', 'MALE'),
                    const SizedBox(width: 12),
                    _genderButton('여자', 'FEMALE'),
                  ],
                ),

                const SizedBox(height: 20),

                /// 연령
                const Text(
                  '연령',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
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
                    _ageButton('50대+', 'FIFTIES_PLUS'),
                  ],
                ),

                const SizedBox(height: 28),

                /// 완료 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    isValid && !isLoading ? _submitSignup : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isValid
                          ? const Color(0xFFFF6A00)
                          : const Color(0xFFE0E0E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
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
            color: selected
                ? const Color(0xFFFFF1E8)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFF6A00)
                  : const Color(0xFFE0E0E0),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFFF6A00)
                  : Colors.black87,
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
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF1E8)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF6A00)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected
                ? const Color(0xFFFF6A00)
                : Colors.black87,
          ),
        ),
      ),
    );
  }
}