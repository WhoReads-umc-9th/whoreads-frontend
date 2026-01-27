import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  /// 좌우 패딩
  final double horizontalPadding;

  /// 기본 하단 여백
  final double baseBottomPadding;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.horizontalPadding = 24,
    this.baseBottomPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          math.max(baseBottomPadding, viewInsetsBottom + 12),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: enabled ? Colors.black : const Color(0xFFE5E7EB),
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
