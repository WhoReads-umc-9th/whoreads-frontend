import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/books/BookDetailPage.dart';

import 'release_readiness_test.dart' show FakeApi, jsonResponse;

String ymd(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime kstToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 9));
  return DateTime(now.year, now.month, now.day);
}

// Stateful API fake: rejects disallowed fields and keeps omitted fields intact.
class UserBookServer {
  String? status = 'WISH';
  int? page = 25;
  int? total = 248;
  String? start;
  String? end;
  int? patchFailure;
  int? postFailure;
  bool failRefresh = false;
  bool staleLibraryDate = false;
  bool ignoreDateUpdates = false;
  Completer<void>? patchGate;
  final requests = <RequestOptions>[];

  List<RequestOptions> get patches =>
      requests.where((r) => r.method == 'PATCH').toList();

  Future<ResponseBody> respond(RequestOptions request) async {
    requests.add(request);
    if (request.path == '/books/42/detail') {
      if (failRefresh && patches.isNotEmpty) return jsonResponse({}, 503);
      return jsonResponse({
        'result': {
          'title': '상태 변경 검증 도서',
          'author_name': '테스트 저자',
          'total_page': total,
          'quotes': [],
          if (status != null)
            'reading_info': {
              'user_book_id': 88,
              'reading_status': status,
              if (page != null) 'reading_page': page,
              if (total != null) 'total_page': total,
              if (start != null) 'started_at': start,
              if (end != null) 'completed_at': end,
            },
        },
      });
    }
    if (request.path == '/me/library/list') {
      return jsonResponse({
        'is_success': true,
        'result': {
          'books': [
            if (staleLibraryDate && request.queryParameters['status'] == status)
              {
                'user_book_id': 88,
                'book': {'id': 42, 'total_page': total},
                'completed_at': '2026-01-02',
              },
          ],
        },
      });
    }
    if (request.method == 'POST' && request.path == '/me/library/book/42') {
      if (postFailure != null) return jsonResponse({}, postFailure!);
      status = 'WISH';
      page = null;
      start = end = null;
      return jsonResponse({
        'result': {'user_book_id': 88},
      }, 201);
    }
    if (request.method == 'PATCH' && request.path == '/me/library/book/88') {
      await patchGate?.future;
      if (patchFailure != null) {
        return jsonResponse({'message': '서버에서 변경을 거절했습니다.'}, patchFailure!);
      }
      final body = Map<String, dynamic>.from(request.data as Map);
      if (!body.containsKey('reading_status')) {
        return jsonResponse({'message': '서버 내부 오류가 발생했습니다.'}, 500);
      }
      final nextStatus = body['reading_status'] as String? ?? status;
      if ((nextStatus == 'WISH' &&
              body.keys.any((k) => k != 'reading_status')) ||
          (nextStatus != 'READING' && body.containsKey('reading_page'))) {
        return jsonResponse({'message': '이 상태에서는 입력할 수 없는 필드입니다.'}, 400);
      }
      final nextPage = body['reading_page'] as int? ?? page;
      if (body.containsKey('reading_page') &&
          (nextPage! < 1 || (total != null && nextPage > total!))) {
        return jsonResponse({'message': '읽은 페이지가 올바르지 않습니다.'}, 400);
      }
      final nextStart = body['started_at'] as String? ?? start;
      var nextEnd = body['completed_at'] as String? ?? end;
      if (nextStart != null &&
          nextEnd != null &&
          nextStart.compareTo(nextEnd) > 0) {
        if (nextStatus == 'READING' &&
            body.containsKey('started_at') &&
            !body.containsKey('completed_at')) {
          nextEnd = null;
        } else {
          return jsonResponse({'message': '시작일은 완료일보다 늦을 수 없습니다.'}, 400);
        }
      }
      status = nextStatus;
      if (!ignoreDateUpdates) {
        start = nextStart;
        end = nextEnd;
      }
      page = nextPage;
      return jsonResponse({}, 204);
    }
    if (request.method == 'DELETE' && request.path == '/me/library/book/88') {
      status = null;
      page = null;
      start = end = null;
      return jsonResponse({}, 204);
    }
    throw StateError('Unexpected request: ${request.method} ${request.path}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserBookServer server;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  setUp(() {
    server = UserBookServer();
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.httpClientAdapter = FakeApi(server.respond);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: BookDetailPage(bookId: 42)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseDate(
    WidgetTester tester,
    String label,
    DateTime date,
  ) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '${date.month}/${date.day}/${date.year}',
    );
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Reading button saves immediately with a KST start date and no page requirement',
    (tester) async {
      server.page = null;
      await open(tester);
      await tester.tap(find.text('읽는 중'));
      await tester.pumpAndSettle();
      expect(server.patches.single.data, {
        'reading_status': 'READING',
        'started_at': ymd(kstToday()),
      });
      expect(server.status, 'READING');
      expect(find.text('-/248p'), findsOneWidget);
      expect(find.text('페이지 수정'), findsOneWidget);
      expect(find.text('저장'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Complete sends no page and displays total without changing saved progress',
    (tester) async {
      server.status = 'READING';
      server.start = '2026-01-01';
      await open(tester);
      await tester.tap(find.text('다 읽음'));
      await tester.pumpAndSettle();
      expect(server.patches.single.data, {
        'reading_status': 'COMPLETE',
        'completed_at': ymd(kstToday()),
      });
      expect(server.page, 25);
      expect(find.text('248/248p'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('페이지 수정'), findsNothing);
      await tester.tap(find.text('읽는 중'));
      await tester.pumpAndSettle();
      expect(server.patches.last.data, {'reading_status': 'READING'});
      expect(find.text('25/248p'), findsOneWidget);
      expect(server.end, ymd(kstToday()));
      expect(find.text('-'), findsOneWidget);
    },
  );

  testWidgets(
    'Switching back and forth preserves the users saved dates and pages',
    (tester) async {
      server.status = 'COMPLETE';
      server.start = '2026-01-01';
      server.end = '2026-01-02';
      await open(tester);
      for (final label in ['읽는 중', '담아둠', '다 읽음']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(server.patches.map((r) => r.data), [
        {'reading_status': 'READING'},
        {'reading_status': 'WISH'},
        {'reading_status': 'COMPLETE'},
      ]);
      expect(server.start, '2026-01-01');
      expect(server.end, '2026-01-02');
      expect(server.page, 25);
      expect(find.text('2026.01.02'), findsOneWidget);
    },
  );

  for (final label in ['담아둠', '읽는 중', '다 읽음']) {
    testWidgets(
      'A new book can go directly to $label, using the POST userBook ID',
      (tester) async {
        server.status = null;
        await open(tester);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final writes = server.requests.where((r) => r.method != 'GET').toList();
        expect(writes.first.method, 'POST');
        expect(writes.first.path, '/me/library/book/42');
        if (label == '담아둠') {
          expect(writes, hasLength(1));
          expect(server.status, 'WISH');
        } else {
          expect(writes, hasLength(2));
          expect(writes.last.path, '/me/library/book/88');
          expect(writes.last.data, {
            'reading_status': label == '읽는 중' ? 'READING' : 'COMPLETE',
            'started_at': ymd(kstToday()),
            if (label == '다 읽음') 'completed_at': ymd(kstToday()),
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Missing dates remain empty and authoritative detail avoids stale library data',
    (tester) async {
      server.status = 'READING';
      server.staleLibraryDate = true;
      await open(tester);
      expect(find.text('-'), findsNWidgets(2));
      expect(
        server.requests.where((r) => r.path == '/me/library/list'),
        isEmpty,
      );
      expect(server.patches, isEmpty);
    },
  );

  testWidgets(
    'Selected status and repeated taps while saving do not submit again',
    (tester) async {
      server.status = 'READING';
      await open(tester);
      await tester.tap(find.text('읽는 중'));
      expect(server.patches, isEmpty);
      server.patchGate = Completer<void>();
      await tester.tap(find.text('다 읽음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다 읽음'));
      await tester.tap(find.text('담아둠'));
      expect(server.patches, hasLength(1));
      server.patchGate!.complete();
      await tester.pumpAndSettle();
      expect(server.status, 'COMPLETE');
    },
  );

  for (final code in [400, 500]) {
    testWidgets(
      'HTTP $code retains the previous status and shows the server error',
      (tester) async {
        server.patchFailure = code;
        await open(tester);
        await tester.tap(find.text('읽는 중'));
        await tester.pumpAndSettle();
        expect(server.status, 'WISH');
        expect(find.text('독서량'), findsNothing);
        expect(find.text('서버에서 변경을 거절했습니다.'), findsOneWidget);
        if (code == 400) {
          await tester.tap(find.text('확인'));
          await tester.pumpAndSettle();
        }
        server.patchFailure = null;
        await tester.tap(find.text('읽는 중'));
        await tester.pumpAndSettle();
        expect(server.status, 'READING');
      },
    );
  }

  testWidgets('Creation failure never proceeds to PATCH', (tester) async {
    server.status = null;
    server.postFailure = 503;
    await open(tester);
    await tester.tap(find.text('다 읽음'));
    await tester.pumpAndSettle();
    expect(server.patches, isEmpty);
    expect(find.text('추가'), findsOneWidget);
    expect(find.text('독서량'), findsNothing);
  });

  testWidgets('A successful save is retained if its refresh fails', (
    tester,
  ) async {
    await open(tester);
    server.failRefresh = true;
    await tester.tap(find.text('다 읽음'));
    await tester.pumpAndSettle();
    expect(find.text('248/248p'), findsOneWidget);
    expect(find.text('저장은 완료했지만 최신 정보를 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets(
    'Page editing validates limits, sends the current status, and allows the final page',
    (tester) async {
      server.status = 'READING';
      await open(tester);
      await tester.tap(find.text('페이지 수정'));
      await tester.pumpAndSettle();
      for (final value in ['', '0', '-1', '249', '1.5']) {
        await tester.enterText(find.byType(TextField), value);
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        expect(server.patches, isEmpty);
        expect(find.byType(AlertDialog), findsOneWidget);
      }
      await tester.enterText(find.byType(TextField), '248');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(server.patches.single.data, {
        'reading_status': 'READING',
        'reading_page': 248,
      });
      expect(server.status, 'READING');
      expect(find.text('248/248p'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancelling page or date editing sends nothing', (tester) async {
    server.status = 'READING';
    await open(tester);
    await tester.tap(find.text('페이지 수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      kstToday(),
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(server.patches, isEmpty);
    expect(server.start, isNull);
  });

  testWidgets(
    'Complete rejects a start after its saved end before making a request',
    (tester) async {
      server.status = 'COMPLETE';
      server.start = '2026-01-01';
      server.end = '2026-01-02';
      await open(tester);
      await chooseDate(tester, '시작', kstToday());
      expect(server.patches, isEmpty);
      expect(find.text('입력할 수 없습니다'), findsOneWidget);
      expect(server.start, '2026-01-01');
    },
  );

  testWidgets(
    'Rereading sends a later start without an end and accepts the cleared completion date',
    (tester) async {
      server.status = 'READING';
      server.start = '2026-01-01';
      server.end = '2026-01-02';
      server.staleLibraryDate = true;
      await open(tester);
      await chooseDate(tester, '시작', kstToday());
      expect(server.patches.single.data, {
        'reading_status': 'READING',
        'started_at': ymd(kstToday()),
      });
      expect(server.end, isNull);
      expect(server.page, 25);
      expect(find.text('2026.01.02'), findsNothing);
      await tester.tap(find.text('다 읽음'));
      await tester.pumpAndSettle();
      expect(server.patches.last.data, {
        'reading_status': 'COMPLETE',
        'completed_at': ymd(kstToday()),
      });
    },
  );

  testWidgets(
    'Completion date editing sends the current status and changed date and disallows future input',
    (tester) async {
      server.status = 'COMPLETE';
      server.start = '2026-01-01';
      await open(tester);
      await chooseDate(tester, '종료', kstToday().add(const Duration(days: 1)));
      expect(server.patches, isEmpty);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await chooseDate(tester, '종료', kstToday());
      expect(server.patches.single.data, {
        'reading_status': 'COMPLETE',
        'completed_at': ymd(kstToday()),
      });
      expect(server.start, '2026-01-01');
    },
  );

  testWidgets(
    'Complete with unknown total pages does not show fabricated completion progress',
    (tester) async {
      server.status = 'COMPLETE';
      server.total = null;
      await open(tester);
      expect(find.text('-/-p'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
    },
  );

  testWidgets(
    'A partially successful add retries PATCH without creating a duplicate',
    (tester) async {
      server.status = null;
      server.patchFailure = 400;
      await open(tester);
      await tester.tap(find.text('다 읽음'));
      await tester.pumpAndSettle();
      expect(server.status, 'WISH');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      server.patchFailure = null;
      await tester.tap(find.text('다 읽음'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(server.patches, hasLength(2));
      expect(server.status, 'COMPLETE');
    },
  );

  testWidgets(
    'A server that ignores date edits is reported instead of showing an unpersisted date',
    (tester) async {
      server.status = 'READING';
      server.start = '2026-01-01';
      server.ignoreDateUpdates = true;
      await open(tester);
      await chooseDate(tester, '시작', kstToday());
      expect(server.start, '2026-01-01');
      expect(find.text('시작'), findsOneWidget);
      expect(find.text('2026.01.01'), findsOneWidget);
      expect(find.text('날짜 변경이 서버에 반영되지 않았습니다. 다시 확인해주세요.'), findsOneWidget);
    },
  );

  testWidgets('Deleting and adding again never reuses old reading dates', (
    tester,
  ) async {
    server.status = 'COMPLETE';
    server.start = '2026-01-01';
    server.end = '2026-01-02';
    await open(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('수정'), findsNothing);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('읽는 중'));
    await tester.pumpAndSettle();
    expect(server.patches.single.data, {
      'reading_status': 'READING',
      'started_at': ymd(kstToday()),
    });
    expect(server.end, isNull);
  });

  testWidgets(
    'A small phone can scroll to dates and edit a page with the keyboard open',
    (tester) async {
      server.status = 'READING';
      await open(tester, size: const Size(320, 568));
      await tester.ensureVisible(find.text('페이지 수정'));
      await tester.tap(find.text('페이지 수정'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(server.patches.single.data, {
        'reading_status': 'READING',
        'reading_page': 100,
      });
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('시작'));
      await tester.tap(find.text('시작'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
