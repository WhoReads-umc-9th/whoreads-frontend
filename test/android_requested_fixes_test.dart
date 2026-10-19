import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/auth/find_account_page.dart';
import 'package:whoreads/screens/auth/login_page.dart';
import 'package:whoreads/screens/auth/reset_password_page.dart';
import 'package:whoreads/screens/books/BookDetailPage.dart';
import 'package:whoreads/screens/celebrities/celebrities_book_page.dart';
import 'package:whoreads/screens/dna_test/DnaResultPage.dart';
import 'package:whoreads/screens/dna_test/dna_test_page.dart';
import 'package:whoreads/screens/users/profile.dart';

import 'release_readiness_test.dart' show FakeApi, jsonResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <RequestOptions>[];
  var added = false;
  var retested = false;
  var savedDna = true;

  Map<String, Object> dna() => {
    'result_headline': retested ? "'다시 찾은 독서 목적'" : "'저장된 독서 목적'",
    'description': ['책으로 세상을 이해합니다.'],
    'celebrity_id': 7,
    'celebrity_name': '추천 인물',
    'image_url': '',
    'job_tags': ['작가'],
  };

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  setUp(() {
    requests.clear();
    added = false;
    retested = false;
    savedDna = true;
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.httpClientAdapter = FakeApi((request) {
      requests.add(request);
      switch (request.path) {
        case '/members/me':
          return jsonResponse({'result': {'nickname': '테스트 독자'}});
        case '/members/me/follows':
          return jsonResponse({'result': []});
        case '/notifications/me/settings':
          return jsonResponse({'result': {
            'follow_setting': {'id': 1, 'is_enabled': true},
            'routine_settings': [],
          }});
        case '/dna/results':
          if (request.method == 'POST') {
            retested = true;
            savedDna = true;
          }
          return savedDna ? jsonResponse({'result': dna()}) : jsonResponse({}, 404);
        case '/dna/questions/root':
          return jsonResponse({'result': {
            'id': 1,
            'content': '독서 목적',
            'options': [{'id': 11, 'content': '첫 번째 답변', 'track_code': 'COMFORT'}],
          }});
        case '/dna/questions':
          return jsonResponse({'result': {'questions': [
            for (var i = 2; i <= 5; i++) {
              'id': i,
              'content': '질문 $i',
              'options': [{'id': i * 10, 'content': '답변 $i'}],
            },
          ]}});
        case '/celebrities/7':
          return jsonResponse({'id': 7, 'name': '추천 인물', 'image_url': '', 'job_tags': ['작가']});
        case '/quotes/celebrities/7':
          return jsonResponse({'result': [
            {'id': 9001, 'book_id': 42, 'book_title': '연결 검증 도서', 'book_author': '테스트 저자'},
          ]});
        case '/members/follow/7':
          return jsonResponse({'result': false});
        case '/me/library/list':
          return jsonResponse({'is_success': true, 'result': {
            'books': added && request.queryParameters['status'] == 'WISH' ? [
              {'user_book_id': 88, 'book': {'id': 42}},
            ] : [],
          }});
        case '/me/library/book/42':
          added = true;
          return jsonResponse({'result': {'user_book_id': 88}}, 201);
        case '/books/42/detail':
          return jsonResponse({'result': {
            'title': '연결 검증 도서', 'author_name': '테스트 저자', 'total_page': 100,
            'reading_info': {'reading_status': 'READING', 'reading_page': 25, 'user_book_id': 88},
            'quotes': [],
          }});
        default:
          return jsonResponse({'is_success': true, 'result': {}});
      }
    });
  });

  void phone(WidgetTester tester, {double width = 360}) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Recommendation tap uses book ID, add stays on list, and typography is consistent', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: CelebritiesBookPage(celebrityId: 7)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.byType(BookDetailPage), findsNothing);
    expect(find.text('추가됨'), findsOneWidget);
    await tester.tap(find.text('연결 검증 도서'));
    await tester.pumpAndSettle();
    expect(find.byType(BookDetailPage), findsOneWidget);
    expect(requests.where((r) => r.path == '/books/42/detail'), hasLength(1));
    expect(requests.any((r) => r.path == '/books/9001/detail'), isFalse);
    final percent = tester.widget<Text>(find.text('25%'));
    final pages = tester.widget<Text>(find.text('25/100p'));
    expect(percent.style!.fontSize, pages.style!.fontSize);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('추가됨'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Adding a book loads its page count and supports direct status and page updates', (tester) async {
    phone(tester);
    var status = 'WISH';
    int? page;
    ApiClient.dio.httpClientAdapter = FakeApi((request) {
      requests.add(request);
      if (request.path == '/books/42/detail') {
        return jsonResponse({'result': {
          'title': '새로 담은 책', 'author_name': '저자', 'quotes': [],
          'reading_info': added ? {
            'user_book_id': 88, 'reading_status': status,
            if (page != null) 'reading_page': page,
            'total_page': 484,
          } : null,
        }});
      }
      if (request.path == '/me/library/list') {
        return jsonResponse({'result': {'books': []}});
      }
      if (request.path == '/me/library/book/42') {
        added = true;
        return jsonResponse({'result': {'user_book_id': 88}}, 201);
      }
      if (request.path == '/me/library/book/88') {
        status = request.data['reading_status'] as String? ?? status;
        page = request.data['reading_page'] as int? ?? page;
        return jsonResponse({}, 204);
      }
      return jsonResponse({'is_success': true, 'result': {}});
    });
    await tester.pumpWidget(const MaterialApp(home: BookDetailPage(bookId: 42)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.path == '/books/42/detail'), hasLength(2));
    await tester.tap(find.text('읽는 중'));
    await tester.pumpAndSettle();
    expect(find.text('-/484p'), findsOneWidget);
    final statusPatch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(statusPatch.path, '/me/library/book/88');
    expect(statusPatch.data['reading_status'], 'READING');
    expect((statusPatch.data as Map).containsKey('reading_page'), isFalse);
    await tester.tap(find.text('페이지 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '25');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final pagePatch = requests.lastWhere((r) => r.method == 'PATCH');
    expect(pagePatch.path, '/me/library/book/88');
    expect(pagePatch.data, {'reading_page': 25});
    expect(find.text('25/484p'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile opens saved DNA, supports cancellation and retest, then refreshes profile', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('독서 DNA'));
    await tester.tap(find.text('독서 DNA'));
    await tester.pumpAndSettle();
    expect(find.byType(DnaResultPage), findsOneWidget);
    expect(find.byType(DnaTestPage), findsNothing);
    expect(find.text("'저장된 독서 목적'"), findsOneWidget);
    await tester.ensureVisible(find.text('다시 테스트하기'));
    await tester.tap(find.text('다시 테스트하기'));
    await tester.pumpAndSettle();
    expect(find.text('첫 번째 답변'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text("'저장된 독서 목적'"), findsOneWidget);
    await tester.ensureVisible(find.text('다시 테스트하기'));
    await tester.tap(find.text('다시 테스트하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('첫 번째 답변'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    for (var i = 2; i <= 5; i++) {
      await tester.tap(find.text('답변 $i'));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
    }
    expect(find.text("'다시 찾은 독서 목적'"), findsOneWidget);
    expect(find.byType(DnaResultPage), findsOneWidget);
    expect(requests.where((r) => r.path == '/dna/results' && r.method == 'POST'), hasLength(1));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('다시 찾은 독서 목적')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile without DNA starts a first test through the introduction dialog', (tester) async {
    savedDna = false;
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('독서 DNA'));
    await tester.tap(find.text('독서 DNA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1분 만에 확인하기'));
    await tester.pumpAndSettle();
    expect(find.byType(DnaTestPage), findsOneWidget);
    expect(find.text('첫 번째 답변'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 384.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Login recovery rows remain separate at width $width and text scale $scale', (tester) async {
        phone(tester, width: width);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: const LoginPage(),
        ));
        await tester.pumpAndSettle();
        final passwordRow = tester.getRect(find.text('비밀번호 재설정'));
        final accountRow = tester.getRect(find.text('계정이 기억나지 않나요?'));
        expect(accountRow.top, greaterThan(passwordRow.bottom));
        expect(tester.takeException(), isNull);
        if (width == 360 && scale == 1) {
          await tester.tap(find.text('비밀번호 재설정'));
          await tester.pumpAndSettle();
          expect(find.byType(ResetPasswordPage), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.text('계정 찾기'));
          await tester.pumpAndSettle();
          expect(find.byType(FindAccountPage), findsOneWidget);
        }
      });
    }
  }
}
