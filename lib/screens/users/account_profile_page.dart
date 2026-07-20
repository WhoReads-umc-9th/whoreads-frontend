import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class AccountProfilePage extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const AccountProfilePage({
    super.key,
    required this.userInfo,
  });

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  static const Color primaryOrange = Color(0xFFFF6A00);

  final TextEditingController _nicknameCtrl = TextEditingController();
  final FocusNode _nicknameFocus = FocusNode();

  late final String _initialNickname;
  late final String? _initialGender;
  late final String? _initialAge;

  String? selectedGender;
  String? selectedAge;
  bool isLoading = false;

  bool get _hasChanges =>
      _nicknameCtrl.text.trim() != _initialNickname ||
      selectedGender != _initialGender ||
      selectedAge != _initialAge;

  bool get _canSave =>
      _hasChanges &&
      _nicknameCtrl.text.trim().isNotEmpty &&
      selectedGender != null &&
      selectedAge != null;

  @override
  void initState() {
    super.initState();
    _initialNickname = widget.userInfo['nickname']?.toString() ?? '';
    _initialGender = widget.userInfo['gender']?.toString();
    _initialAge = widget.userInfo['age_group']?.toString();

    _nicknameCtrl.text = _initialNickname;
    selectedGender = _initialGender;
    selectedAge = _initialAge;

    _nicknameCtrl.addListener(() => setState(() {}));
    _nicknameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  /// 성공하면 null, 실패하면 사용자에게 보여줄 메시지를 반환한다.
  Future<String?> _patch(String path, Map<String, dynamic> body) async {
    final response = await ApiClient.dio.patch(path, data: body);
    final decoded = response.data;
    final isSuccess = (response.statusCode == 200 || response.statusCode == 201) &&
        !(decoded is Map && decoded['is_success'] == false);

    if (isSuccess) return null;
    return (decoded is Map ? decoded['message']?.toString() : null) ??
        '프로필 저장에 실패했습니다.';
  }

  Future<void> _submit() async {
    if (!_canSave || isLoading) return;

    setState(() => isLoading = true);

    try {
      // 통합 수정 API가 없어서 변경된 항목만 각각의 엔드포인트로 보낸다.
      final nickname = _nicknameCtrl.text.trim();
      String? error;

      if (nickname != _initialNickname) {
        error = await _patch('/members/me/nickname', {'nickname': nickname});
      }
      if (error == null && selectedGender != _initialGender) {
        error = await _patch('/members/me/gender', {'gender': selectedGender});
      }
      if (error == null && selectedAge != _initialAge) {
        error = await _patch('/members/me/age', {'age_group': selectedAge});
      }

      if (!mounted) return;

      if (error == null) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 저장 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNicknameFocused = _nicknameFocus.hasFocus;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            '계정 관리',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '닉네임',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nicknameCtrl,
                        focusNode: _nicknameFocus,
                        decoration: InputDecoration(
                          hintText: '예) 홍길동',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isNicknameFocused
                                  ? primaryOrange
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: primaryOrange),
                          ),
                          suffixIcon: _nicknameCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Color(0xFFBDBDBD),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _nicknameCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '성별',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _genderButton('남자', 'MALE'),
                          const SizedBox(width: 12),
                          _genderButton('여자', 'FEMALE'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '연령',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
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
                          _ageButton('50대+', 'FIFTY_PLUS'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canSave && !isLoading ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSave
                          ? Colors.black
                          : const Color(0xFFE0E0E0),
                      disabledBackgroundColor: const Color(0xFFE0E0E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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
                        : Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _canSave ? Colors.white : Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
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
              color: selected ? primaryOrange : const Color(0xFFE0E0E0),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? primaryOrange : Colors.black87,
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

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedAge = value),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFF1E8)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primaryOrange : const Color(0xFFE0E0E0),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: selected ? primaryOrange : Colors.black87,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
