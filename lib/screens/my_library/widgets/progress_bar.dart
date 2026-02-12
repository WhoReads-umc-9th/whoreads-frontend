import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final double progress;

  const ProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          color: const Color(0xFFFF6A00),
          backgroundColor: Colors.grey.shade300,
        ),
        const SizedBox(height: 4),
        Text('${(progress * 100).toInt()}%'),
      ],
    );
  }
}
