import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/models/dna_models.dart';
import 'package:whoreads/screens/dna_test/DnaResultPage.dart';
import 'package:whoreads/widgets/auth/login_method_sheet.dart';
import 'package:whoreads/widgets/auth/signup_terms_sheet.dart';

void main() {
  for (final name in ['DNA result', 'login sheet', 'signup terms']) {
    testWidgets('Portrait QA: $name at 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final Widget page = switch (name) {
        'DNA result' => DnaResultPage(
          result: DnaResult(
            headline: "'마음의 위로'",
            description: ['독서로 위로를 얻는 사람입니다.'],
            celebrityId: 1,
            celebrityName: '테스트 인물',
            imageUrl: '',
            jobTags: ['작가'],
          ),
        ),
        'login sheet' => Scaffold(
          body: LoginMethodSheet(onKakaoLogin: () {}, onEmailLogin: () {}),
        ),
        _ => Scaffold(body: SignupTermsSheet(onAgreed: () {})),
      };
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
