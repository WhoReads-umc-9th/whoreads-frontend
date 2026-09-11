import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/auth/token_storage.dart';
import '../../core/network/api_client.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/notification/fcm_service.dart';
import '../my_library/my_library_page.dart';

/// 회원가입을 완료한 후에만 홈으로 진입하는 추가 정보 입력 화면.
class SignupProfilePage extends StatefulWidget {
  final String? email;
  final String? loginId;
  final String? password;
  final String? registrationToken;
  final String? initialNickname;

  const SignupProfilePage.email({
    super.key,
    required String this.email,
    required String this.loginId,
    required String this.password,
  }) : registrationToken = null,
       initialNickname = null;

  const SignupProfilePage.kakao({
    super.key,
    required String this.registrationToken,
    this.initialNickname,
  }) : email = null,
       loginId = null,
       password = null;

  @override
  State<SignupProfilePage> createState() => _SignupProfilePageState();
}

class _SignupProfilePageState extends State<SignupProfilePage> {
  late final TextEditingController _nicknameCtrl;
  String? selectedGender;
  String? selectedAge;
  bool isLoading = false;
  static const _orange = Color(0xFFFF5900);

  @override
  void initState() {
    super.initState();
    _nicknameCtrl = TextEditingController(text: widget.initialNickname ?? '');
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  bool get isValid =>
      _nicknameCtrl.text.trim().isNotEmpty &&
      selectedGender != null &&
      selectedAge != null;

  void _openHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyLibraryPage()),
      (_) => false,
    );
  }

  Future<void> _submitSignup() async {
    if (!isValid || isLoading) return;
    setState(() => isLoading = true);

    try {
      if (widget.registrationToken != null) {
        final error = await KakaoAuthService().signup(
          registrationToken: widget.registrationToken!,
          nickname: _nicknameCtrl.text.trim(),
          gender: selectedGender!,
          ageGroup: selectedAge!,
        );
        if (!mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
          return;
        }
        _openHome();
        return;
      }
      final response = await ApiClient.dio.post(
        '/auth/signup',
        data: {
          "request": {
            "login_id": widget.loginId,
            "email": widget.email,
            "password": widget.password,
          },
          "member_info": {
            "nickname": _nicknameCtrl.text.trim(),
            "gender": selectedGender,
            "age_group": selectedAge,
          },
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
        _openHome();
      } else {
        final message = decoded['message'] ?? '회원가입에 실패했습니다.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원가입 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: isLoading
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '닉네임 / 성별 / 연령을 입력해주세요',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF19191B),
                  ),
                ),
                const SizedBox(height: 32),
                _label('닉네임'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nicknameCtrl,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '닉네임을 입력해주세요',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: _nicknameCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.cancel,
                              color: Color(0xFFC9CACC),
                              size: 20,
                            ),
                            onPressed: isLoading
                                ? null
                                : () => setState(_nicknameCtrl.clear),
                          ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _nicknameCtrl.text.isEmpty
                            ? const Color(0xFFC9CACC)
                            : _orange,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _orange),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label('성별'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _choice('남자', 'MALE', gender: true),
                    const SizedBox(width: 8),
                    _choice('여자', 'FEMALE', gender: true),
                  ],
                ),
                const SizedBox(height: 16),
                _label('연령'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _choice('10대', 'TEENAGERS'),
                    const SizedBox(width: 4),
                    _choice('20대', 'TWENTIES'),
                    const SizedBox(width: 4),
                    _choice('30대', 'THIRTIES'),
                    const SizedBox(width: 4),
                    _choice('40대', 'FORTIES'),
                    const SizedBox(width: 4),
                    _choice('50대+', 'FIFTY_PLUS'),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isValid && !isLoading ? _submitSignup : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF19191B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFC9CACC),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 14, color: Color(0xFF6C6C6C)),
  );

  Widget _choice(String label, String value, {bool gender = false}) {
    final selected = (gender ? selectedGender : selectedAge) == value;
    return Expanded(
      child: SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: isLoading
              ? null
              : () => setState(() {
                  if (gender) {
                    selectedGender = value;
                  } else {
                    selectedAge = value;
                  }
                }),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: selected ? const Color(0xFFFFF6F2) : Colors.white,
            foregroundColor: selected
                ? const Color(0xFF19191B)
                : const Color(0xFF6C6C6C),
            side: BorderSide(
              color: selected ? _orange : const Color(0xFFC9CACC),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
