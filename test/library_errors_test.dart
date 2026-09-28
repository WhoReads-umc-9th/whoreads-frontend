import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/my_library/tabs/saved_tab.dart';
import 'package:whoreads/screens/books/BookDetailPage.dart';
import 'package:whoreads/screens/celebrities/celebrities_page.dart';
import 'package:whoreads/screens/celebrities/celebrities_book_page.dart';
import 'package:whoreads/models/library_book_model.dart';
import 'package:whoreads/services/library_service.dart';
import 'package:whoreads/services/timer/timer_api_service.dart';
import 'release_readiness_test.dart' show FakeApi, jsonResponse;

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    ApiClient.dio.interceptors.clear();
  });
  testWidgets('Library failure is retryable and not shown as empty', (
    tester,
  ) async {
    var failing = true;
    ApiClient.dio.httpClientAdapter = FakeApi(
      (o) => failing
          ? jsonResponse({}, 503)
          : jsonResponse({
              'is_success': true,
              'result': {'books': []},
            }),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SavedTab())),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('아직 담아둔 책이 없어요'), findsNothing);
    failing = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('아직 담아둔 책이 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Book detail failure offers retry instead of add', (
    tester,
  ) async {
    ApiClient.dio.httpClientAdapter = FakeApi((o) => jsonResponse({}, 503));
    await tester.pumpWidget(const MaterialApp(home: BookDetailPage(bookId: 1)));
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('추가'), findsNothing);
  });
  for (final entry in <String, Widget>{
    'book': const BookDetailPage(bookId: 1),
    'celebrities': const CelebritiesPage(),
    'celebrity': const CelebritiesBookPage(celebrityId: 1),
  }.entries) {
    testWidgets('${entry.key} ignores delayed responses after leaving', (
      tester,
    ) async {
      final response = Completer<ResponseBody>();
      ApiClient.dio.httpClientAdapter = FakeApi((o) => response.future);
      await tester.pumpWidget(MaterialApp(home: entry.value));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(jsonResponse({}, 503));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Negative reading page cannot be saved', (tester) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var writes = 0;
    ApiClient.dio.httpClientAdapter = FakeApi((o) {
      if (o.method == 'PATCH') writes++;
      if (o.path.contains('/detail'))
        return jsonResponse({
          'result': {
            'title': 'QA book',
            'author_name': 'QA',
            'genre': 'QA',
            'total_page': 100,
            'reading_info': {
              'user_book_id': 7,
              'reading_status': 'READING',
              'reading_page': 1,
            },
          },
        });
      return jsonResponse({
        'is_success': true,
        'result': {'books': []},
      });
    });
    await tester.pumpWidget(const MaterialApp(home: BookDetailPage(bookId: 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '-1');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('읽은 페이지를 전체 페이지 범위 안에서 입력해주세요.'), findsOneWidget);
  });
  test('Progress is bounded for malformed server page counts', () {
    for (final page in [-1, 101]) {
      final book = LibraryBookModel.fromJson({
        'reading_page': page,
        'book': {'total_page': 100},
      });
      expect(book.progress, page < 0 ? 0 : 1);
    }
  });
  test('Library lookup follows server cursor and parses string IDs', () async {
    final cursors = <Object?>[];
    ApiClient.dio.httpClientAdapter = FakeApi((o) {
      final cursor = o.queryParameters['cursor'];
      cursors.add(cursor);
      return jsonResponse({
        'is_success': true,
        'result': {
          'books': [
            {
              'user_book_id': cursor == null ? '10' : '11',
              'book': {'id': cursor == null ? '1' : '2', 'total_page': '100'},
            },
          ],
          'has_next': cursor == null,
          'next_cursor': cursor == null ? 10 : null,
        },
      });
    });
    final found = await LibraryService.lookupCatalogBookInLibrary(2, size: 1);
    expect(found?.userBookId, 11);
    expect(found?.totalPage, 100);
    expect(cursors, [null, 10]);
  });
  test('No active timer 404 is not a server failure', () async {
    ApiClient.dio.httpClientAdapter = FakeApi(
      (o) => jsonResponse({'is_success': false}, 404),
    );
    expect(await TimerApiService().getActiveSession(), isNull);
  });
}
