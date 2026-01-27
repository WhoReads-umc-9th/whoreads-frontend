import 'package:flutter/material.dart';

class PasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final int minLength;

  /// 값/유효성 변경 콜백
  final void Function(String value, bool isValid) onChanged;

  const PasswordInput({
    super.key,
    required this.controller,
    required this.onChanged,
    this.label = '비밀번호',
    this.hintText = '영문, 숫자 8자리 이상 입력',
    this.minLength = 8,
  });

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _hintColor = Color(0xFFBDBDBD);
  static const Color _labelColor = Color(0xFF9E9E9E);

  bool _obscure = true;

  void _emit() {
    final v = widget.controller.text;
    final ok = v.length >= widget.minLength;
    widget.onChanged(v, ok);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {});
      _emit();
    });
    _emit();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_emit);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

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

        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: _hintColor),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFFBDBDBD),
                  ),
                ),
                if (hasText)
                  IconButton(
                    onPressed: () {
                      widget.controller.clear();
                      _emit();
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFFBDBDBD),
                    ),
                  ),
              ],
            ),
            suffixIconConstraints: const BoxConstraints(
              minHeight: 40,
              minWidth: 96,
            ),
          ),
        ),
      ],
    );
  }
}
