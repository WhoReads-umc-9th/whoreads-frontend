import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimerViewWidget extends StatelessWidget {
  final String timeText;
  final double percentage;

  const TimerViewWidget({super.key, required this.timeText, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TimerPainter(
        percentage: percentage,
        color: const Color(0xFFF84E00),
      ),
      child: SizedBox(
        width: 280, height: 280,
        child: Center(
          child: Text(timeText, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w400)),
        ),
      ),
    );
  }
}

class TimerPainter extends CustomPainter {
  final double percentage;
  final Color color;

  TimerPainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    Paint foregroundPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = math.min(size.width / 2, size.height / 2);

    // 배경 회색 원
    canvas.drawCircle(center, radius, backgroundPaint);

    // 진행중인 주황색 호 (상단에서 시작하도록 -pi/2 만큼 회전)
    double sweepAngle = 2 * math.pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(TimerPainter oldDelegate) => oldDelegate.percentage != percentage;
}

