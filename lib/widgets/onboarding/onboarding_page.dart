import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../screens/onboarding/onboarding_data.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final double svgAreaHeight = MediaQuery.of(context).size.height * 0.46;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          SizedBox(
            height: svgAreaHeight,
            child: _buildSvgArea(context),
          ),

          const SizedBox(height: 20),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.4,
              fontFamily: 'Pretendard Variable',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF767676),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
              fontFamily: 'Pretendard Variable',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSvgArea(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    // 👇 top / bottom SVG 겹치는 구조
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 0,
          child: SvgPicture.asset(
            data.svgTop!,
            width: width * 0.9,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          top: width * 0.3, // 👈 겹침 정도 조절
          child: SvgPicture.asset(
            data.svgBottom!,
            width: width * 0.9,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}