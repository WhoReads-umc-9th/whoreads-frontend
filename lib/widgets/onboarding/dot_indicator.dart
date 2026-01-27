import 'package:flutter/material.dart';

class DotIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;

  const DotIndicator({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool isActive = i == activeIndex;
        return Container(
          width: 6,
          height: 6,
          margin: EdgeInsets.only(right: i == count - 1 ? 0 : 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFFF74E00) : const Color(0xFFCED0D4),
          ),
        );
      }),
    );
  }
}