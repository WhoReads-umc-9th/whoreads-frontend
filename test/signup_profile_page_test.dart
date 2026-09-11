import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/auth/signup_profile_page.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    ApiClient.dio.interceptors.clear();
  });

  for (final kakao in [false, true]) {
    testWidgets('${kakao ? '카카오' : '이메일'} 가입 정보는 홈 진입 전에 필수 입력', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      RequestOptions? request;
      ApiClient.dio.interceptors.clear();
      ApiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 400,
                data: {'is_success': false, 'message': '가입 실패 테스트'},
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: kakao
              ? const SignupProfilePage.kakao(
                  registrationToken: 'test-registration',
                )
              : const SignupProfilePage.email(
                  email: 'test@example.invalid',
                  loginId: 'tester',
                  password: 'test-password',
                ),
        ),
      );
      final submit = find.widgetWithText(ElevatedButton, '완료');
      expect(find.byType(MyLibraryPage), findsNothing);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      await tester.tap(find.text('여자'));
      await tester.tap(find.text('50대+'));
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      await tester.enterText(find.byType(TextField), ' 하리 ');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(request?.path, kakao ? '/auth/kakao/signup' : '/auth/signup');
      final body = request!.data as Map;
      final info = kakao ? body : body['member_info'] as Map;
      expect(info['nickname'], '하리');
      expect(info['gender'], 'FEMALE');
      expect(info['age_group'], 'FIFTY_PLUS');
      expect(find.text('가입 실패 테스트'), findsOneWidget);
      expect(find.byType(MyLibraryPage), findsNothing);
      expect(find.byType(SignupProfilePage), findsOneWidget);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
