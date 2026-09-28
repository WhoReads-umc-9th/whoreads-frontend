// Release regression expectations. All API and platform calls are local fakes.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/dna_test/dna_test_page.dart';
import 'package:whoreads/screens/topics/topics_page.dart';
import 'package:whoreads/screens/auth/login_page.dart';
import 'package:whoreads/screens/auth/signup_profile_page.dart';
import 'package:whoreads/screens/users/account_profile_page.dart';
import 'package:whoreads/services/auth_service.dart';
import 'package:whoreads/services/library_service.dart';
import 'package:whoreads/services/notification/notification_api_service.dart';
import 'package:whoreads/services/notification_setting.dart';
import 'package:whoreads/services/timer/timer_api_service.dart';
import 'package:whoreads/services/timer/timer_service.dart';

class FakeApi implements HttpClientAdapter {
  FakeApi(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = <String, String>{};
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map?;
            switch (call.method) {
              case 'read':
                return tokens[args!['key']];
              case 'write':
                tokens[args!['key']] = args['value'];
                return null;
              case 'deleteAll':
                tokens.clear();
                return null;
            }
            return null;
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_foreground_task/methods'),
          (call) async => call.method == 'isRunningService' ? false : null,
        );
  });

  setUp(() {
    tokens.clear();
    SharedPreferences.setMockInitialValues({});
    // Keep production status validation; remove auth/logging for isolated tests.
    ApiClient.dio.interceptors.clear();
  });

  test('AUTH: offline logout clears local credentials', () async {
    tokens.addAll({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
    });
    ApiClient.dio.httpClientAdapter = FakeApi(
      (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    await AuthService().logout();
    expect(tokens, isEmpty);
  });

  test('AUTH: successful logout clears local credentials', () async {
    tokens['access_token'] = 'test-access';
    ApiClient.dio.httpClientAdapter = FakeApi((o) => jsonResponse({}, 200));
    await AuthService().logout();
    expect(tokens, isEmpty);
  });

  test('TIMER: HTTP 500 completion must report failure', () async {
    ApiClient.dio.httpClientAdapter = FakeApi(
      (o) => jsonResponse({'is_success': false}, 500),
    );
    await expectLater(TimerApiService().completeTimer(7), throwsA(anything));
  });

  test('NOTIFICATIONS: HTTP 500 read-all must report failure', () async {
    ApiClient.dio.httpClientAdapter = FakeApi(
      (o) => jsonResponse({'is_success': false}, 500),
    );
    await expectLater(
      NotificationApiService().readAllNotifications(),
      throwsA(anything),
    );
  });

  test('ROUTINE: save must await server acknowledgement', () async {
    final response = Completer<ResponseBody>();
    ApiClient.dio.httpClientAdapter = FakeApi((o) => response.future);
    var returned = false;
    final saving = NotificationSettingService()
        .addRoutine(
          timePeriod: TimePeriod.am,
          hour: 9,
          minutes: 0,
          days: [Day.monday],
        )
        .then((_) => returned = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final returnedBeforeServer = returned;
    response.complete(jsonResponse({'is_success': true}));
    await saving;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(returnedBeforeServer, isFalse);
  });

  test('LIBRARY: server failure must not become an empty library', () async {
    ApiClient.dio.httpClientAdapter = FakeApi(
      (o) => jsonResponse({'is_success': false}, 503),
    );
    await expectLater(
      LibraryService.fetchBooks(status: 'WISH'),
      throwsA(anything),
    );
  });

  test('LIBRARY: genuine empty response is accepted', () async {
    ApiClient.dio.httpClientAdapter = FakeApi(
      (o) => jsonResponse({
        'is_success': true,
        'result': {'books': []},
      }),
    );
    expect(await LibraryService.fetchBooks(status: 'WISH'), isEmpty);
  });

  for (final paused in [true, false]) {
    test(
      'TIMER: ${paused ? 'paused time must not elapse' : 'missing cache must not complete active session'}',
      () async {
        final timer = TimerService();
        ApiClient.dio.httpClientAdapter = FakeApi((o) => jsonResponse({}));
        await timer.resetTimer();
        if (paused) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'timer_session',
            jsonEncode({
              'remainingMinutes': 10,
              'totalReadMinutes': 0,
              'status': 'PAUSED',
              'savedAt': DateTime.now()
                  .subtract(const Duration(minutes: 20))
                  .toIso8601String(),
            }),
          );
        }
        final calls = <String>[];
        ApiClient.dio.httpClientAdapter = FakeApi((o) {
          calls.add(o.path);
          return jsonResponse({
            'result': {
              'session_id': 7,
              'status': paused ? 'PAUSED' : 'RUNNING',
              'remaining_minutes': 10,
              'total_read_minutes': 0,
              'idle_minutes': 20,
              'focus_block_enabled': false,
              'white_noise_enabled': false,
            },
          });
        });
        final result = await timer.checkRecoveryState();
        final completed = calls.any((p) => p.endsWith('/complete'));
        ApiClient.dio.httpClientAdapter = FakeApi((o) => jsonResponse({}));
        await timer.resetTimer();
        expect(
          completed,
          isFalse,
          reason: 'remaining_minutes=10; result=$result',
        );
      },
    );
  }

  testWidgets('DNA: retry preserves the same answer IDs', (tester) async {
    final submissions = <List<dynamic>>[];
    Map<String, Object> question(int id, int step) => {
      'id': id,
      'step': step,
      'content': 'Question $step',
      'options': [
        {'id': id * 10, 'content': 'Answer $step', 'track_code': 'COMFORT'},
      ],
    };
    ApiClient.dio.httpClientAdapter = FakeApi((o) {
      if (o.path == '/dna/questions/root') {
        return jsonResponse({'result': question(1, 1)});
      }
      if (o.path == '/dna/questions') {
        return jsonResponse({
          'result': {
            'questions': [for (var i = 2; i <= 5; i++) question(i, i)],
          },
        });
      }
      submissions.add(List<dynamic>.from(o.data['selected_option_ids']));
      return jsonResponse({'is_success': false}, 500);
    });
    await tester.pumpWidget(const MaterialApp(home: DnaTestPage()));
    await tester.pumpAndSettle();
    for (var i = 1; i <= 5; i++) {
      await tester.tap(find.text('Answer $i'));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(submissions.length, 2);
    expect(submissions[1], submissions[0]);
  });

  testWidgets(
    'TOPICS: server errors must not trigger an unbounded retry loop',
    (tester) async {
      var bookRequests = 0;
      ApiClient.dio.httpClientAdapter = FakeApi((o) async {
        if (o.path == '/books') bookRequests++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonResponse({'is_success': false}, 503);
      });
      await tester.pumpWidget(const MaterialApp(home: TopicsPage()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final observedRequests = bookRequests;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 30));
      expect(observedRequests, lessThanOrEqualTo(3));
    },
  );

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('LAYOUT: auth and profile render at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupProfilePage.email(
            email: 'qa@example.invalid',
            loginId: 'qa',
            password: 'fake-password',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        const MaterialApp(
          home: AccountProfilePage(
            userInfo: {
              'nickname': 'QA',
              'gender': 'FEMALE',
              'age_group': 'FIFTY_PLUS',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
