class OnboardingData {
  final String? svgTop;     // top svg가 있으면 사용
  final String? svgBottom;  // bottom svg가 있으면 사용
  final String? svgSingle;  // 한 장짜리면 사용
  final String title;
  final String description;

  const OnboardingData({
    this.svgTop,
    this.svgBottom,
    this.svgSingle,
    required this.title,
    required this.description,
  }) : assert(
  (svgSingle != null) || (svgTop != null && svgBottom != null),
  'svgSingle 또는 (svgTop + svgBottom) 중 하나는 반드시 제공해야 합니다.',
  );
}

const onboardingPages = <OnboardingData>[
  OnboardingData(
    svgTop: 'assets/images/onboarding/onboarding1_top.svg',
    svgBottom: 'assets/images/onboarding/onboarding1_down.svg',
    title: '유명인은 어떤 책을 읽을까?',
    description:
    '유명인의 실제 독서 맥락을 통해\n책 선택의 부담을 줄여주는 인물 중심 독서 큐레이션이에요',
  ),
  OnboardingData(
    svgTop: 'assets/images/onboarding/onboarding2_top.svg',
    svgBottom: 'assets/images/onboarding/onboarding2_down.svg',
    title: '책 고르는게 제일 어려워요',
    description:
    '내게 맞는 책인지 확신이 없으면\n독서를 시작하는 것부터 부담돼요',
  ),
  OnboardingData(
    svgTop: 'assets/images/onboarding/onboarding3_top.svg',
    svgBottom: 'assets/images/onboarding/onboarding3_down.svg',
    title: "그래서 우리는 '읽는 이유'를 봐요",
    description:
    '당신의 목적과 방식에 일치하는\n유명인의 추천 도서를 알려드릴게요',
  )
];
