// Fake API responses; real signup, token storage, navigation and auth interceptor.
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/auth/login_page.dart';
import 'package:whoreads/screens/auth/signup_profile_page.dart';
import 'package:whoreads/screens/celebrities/celebrities_book_page.dart';
import 'package:whoreads/screens/dna_test/DnaResultPage.dart';
import 'package:whoreads/screens/dna_test/dna_test_page.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';

class SignupApi implements HttpClientAdapter {
  SignupApi(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody reply(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = <String, String>{};
  final requests = <RequestOptions>[];
  var loginFails = false;
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final a = call.arguments as Map?;
            switch (call.method) {
              case 'read':
                return tokens[a!['key']];
              case 'write':
                tokens[a!['key']] = a['value'];
              case 'delete':
                tokens.remove(a!['key']);
              case 'deleteAll':
                tokens.clear();
            }
            return null;
          },
        );
  });
  setUp(() {
    tokens.clear();
    requests.clear();
    loginFails = false;
    ApiClient.dio.httpClientAdapter = SignupApi((o) {
      requests.add(o);
      switch (o.path) {
        case '/auth/signup':
          return reply({
            'is_success': true,
            'result': {
              'access_token': 'signup-access',
              'member': {'nickname': '독자'},
            },
          });
        case '/auth/login':
          return loginFails
              ? reply({'is_success': false}, 503)
              : reply({
                  'is_success': true,
                  'result': {
                    'access_token': 'login-access',
                    'refresh_token': 'login-refresh',
                  },
                });
        case '/members/me':
          return reply({
            'is_success': true,
            'result': {'nickname': '독자'},
          });
        case '/me/library/summary':
          return reply({
            'is_success': true,
            'result': {
              'completed_count': 0,
              'reading_count': 0,
              'total_read_minutes': 0,
            },
          });
        case '/me/library/list':
          return reply({
            'is_success': true,
            'result': {'books': [], 'has_next': false},
          });
        case '/dna/questions/root':
          return reply({
            'is_success': true,
            'result': {
              'id': 1,
              'content': '독서 목적',
              'options': [
                {'id': 11, 'content': '마음의 위로', 'track_code': 'COMFORT'},
              ],
            },
          });
        case '/dna/questions':
          return reply({
            'is_success': true,
            'result': {
              'questions': List.generate(
                4,
                (i) => {
                  'id': i + 2,
                  'content': '질문 ${i + 2}',
                  'options': [
                    {'id': i + 20, 'content': '답변 ${i + 2}'},
                  ],
                },
              ),
            },
          });
        case '/dna/results':
          if (o.method == 'GET') return reply({'is_success': false}, 404);
          return reply({
            'is_success': true,
            'result': {
              'result_headline': "'위로를 찾는'",
              'description': ['독서를 통해 위로를 얻습니다.'],
              'celebrity_id': 1,
              'celebrity_name': '추천 인물',
              'image_url': '',
              'job_tags': ['작가'],
            },
          });
        case '/celebrities/1':
          return reply({
            'id': 1,
            'name': '추천 인물',
            'image_url': '',
            'job_tags': ['작가'],
          });
        case '/quotes/celebrities/1':
          return reply({'is_success': true, 'result': []});
        case '/members/follow/1':
          return reply({'is_success': true, 'result': false});
        default:
          return reply({'is_success': true, 'result': {}});
      }
    });
  });
  Future<void> submitSignup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: SignupProfilePage.email(
          email: 'qa@example.invalid',
          loginId: 'qa-reader',
          password: 'test-password',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '독자');
    await tester.tap(find.text('여자'));
    await tester.tap(find.text('20대'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '완료'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Access-only signup obtains renewable login before DNA recommendations',
    (tester) async {
      await submitSignup(tester);
      expect(tokens, {
        'access_token': 'login-access',
        'refresh_token': 'login-refresh',
      });
      expect(find.byType(MyLibraryPage), findsOneWidget);
      expect(requests.take(2).map((o) => o.path), [
        '/auth/signup',
        '/auth/login',
      ]);
      expect(requests[1].data, {
        'login_id': 'qa-reader',
        'password': 'test-password',
      });
      await tester.tap(
        find
            .ancestor(
              of: find.text('독서 DNA 테스트'),
              matching: find.byType(GestureDetector),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1분 만에 확인하기'));
      await tester.pumpAndSettle();
      expect(find.byType(DnaTestPage), findsOneWidget);
      await tester.tap(find.text('마음의 위로'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '다음'));
      await tester.pumpAndSettle();
      for (var q = 2; q <= 5; q++) {
        await tester.tap(find.text('답변 $q'));
        await tester.pump();
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      }
      expect(find.byType(DnaResultPage), findsOneWidget);
      await tester.tap(find.text('추천 인물의 추천 도서 확인하기'));
      await tester.pumpAndSettle();
      expect(find.byType(CelebritiesBookPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(
        tester
            .widget<CelebritiesBookPage>(find.byType(CelebritiesBookPage))
            .celebrityId,
        1,
      );
      final protected = requests.where((o) => !o.path.startsWith('/auth/'));
      expect(
        protected.every(
          (o) => o.headers['Authorization'] == 'Bearer login-access',
        ),
        isTrue,
      );
      expect(tokens['refresh_token'], 'login-refresh');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Successful signup with failed auto-login opens login without duplicate signup',
    (tester) async {
      loginFails = true;
      await submitSignup(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SignupProfilePage), findsNothing);
      expect(find.text('회원가입이 완료되었습니다. 로그인해주세요.'), findsOneWidget);
      expect(requests.where((o) => o.path == '/auth/signup'), hasLength(1));
      expect(tokens, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
