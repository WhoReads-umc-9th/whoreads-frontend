import 'package:flutter/material.dart';

class EmailInput extends StatefulWidget {
  final TextEditingController emailIdController;

  /// 기본 도메인 목록
  final List<String> domains;

  /// 라벨 텍스트(필요하면 변경)
  final String label;

  /// 힌트 텍스트(아이디)
  final String idHintText;

  /// 힌트 텍스트(도메인)
  final String domainHintText;

  /// 이메일 값/유효성 변경 콜백
  /// - email: "id@domain" 또는 null
  /// - isValid: 활성화 조건 충족 여부
  final void Function(String? email, bool isValid) onChanged;

  const EmailInput({
    super.key,
    required this.emailIdController,
    required this.onChanged,
    this.domains = const [
      'naver.com',
      'gmail.com',
      'hanmail.net',
      'kakao.com',
      'daum.net',
      'icloud.com',
    ],
    this.label = '이메일',
    this.idHintText = '이메일 입력',
    this.domainHintText = '선택',
  });

  @override
  State<EmailInput> createState() => _EmailInputState();
}

class _EmailInputState extends State<EmailInput> {
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _hintColor = Color(0xFFBDBDBD);
  static const Color _labelColor = Color(0xFF9E9E9E);

  static const String _customDomainValue = '__CUSTOM__';

  String? _selectedDomain;
  final TextEditingController _customDomainCtrl = TextEditingController();

  bool get _isCustomDomain => _selectedDomain == _customDomainValue;

  String? get _domainValue {
    if (_selectedDomain == null) return null;
    if (_isCustomDomain) {
      final v = _customDomainCtrl.text.trim();
      return v.isEmpty ? null : v;
    }
    return _selectedDomain;
  }

  void _emit() {
    final emailId = widget.emailIdController.text.trim();
    final domain = _domainValue;

    final emailOk = emailId.isNotEmpty && domain != null;
    final email = emailOk ? '$emailId@$domain' : null;

    widget.onChanged(email, emailOk);
  }

  @override
  void initState() {
    super.initState();
    widget.emailIdController.addListener(_emit);
    _customDomainCtrl.addListener(_emit);
    _emit();
  }

  @override
  void dispose() {
    widget.emailIdController.removeListener(_emit);
    _customDomainCtrl.removeListener(_emit);
    _customDomainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _labelColor,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            // 아이디 입력
            Expanded(
              flex: 6,
              child: TextField(
                controller: widget.emailIdController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.idHintText,
                  hintStyle: const TextStyle(color: _hintColor),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),
            const Text(
              '@',
              style: TextStyle(
                fontSize: 16,
                color: _hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),

            // 도메인
            Expanded(
              flex: 6,
              child: _isCustomDomain
                  ? TextField(
                controller: _customDomainCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '직접입력',
                  hintStyle: const TextStyle(color: _hintColor),
                  suffixIcon: IconButton(
                    tooltip: '도메인 선택으로 변경',
                    onPressed: () {
                      setState(() {
                        _customDomainCtrl.clear();
                        _selectedDomain = null;
                      });
                      _emit();
                    },
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
              )
                  : DropdownButtonFormField<String>(
                value: _selectedDomain,
                isExpanded: true,
                onChanged: (v) {
                  setState(() {
                    _selectedDomain = v;
                    if (v != _customDomainValue) {
                      _customDomainCtrl.clear();
                    }
                  });
                  _emit();
                },
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.domainHintText,
                  hintStyle: const TextStyle(color: _hintColor),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                items: [
                  ...widget.domains.map(
                        (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _customDomainValue,
                    child: Text('직접입력'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
