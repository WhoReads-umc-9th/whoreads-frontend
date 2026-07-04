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
    final double screenHeight = MediaQuery.of(context).size.height;

    final double svgAreaHeight = screenHeight < 800
        ? screenHeight * 0.38
        : screenHeight * 0.46;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSvgArea(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

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
          top: width * 0.3,
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