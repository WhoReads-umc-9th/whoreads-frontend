import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/celebrities/celebrities_book_page.dart';
import 'package:whoreads/screens/celebrities/celebrities_page.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';
import 'package:whoreads/screens/topics/topics_page.dart';

import 'support/ui_fix_fixtures.dart';

class _TabApi extends UiFixApi {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body;
    if (options.path == '/members/me') {
      body = {
        'result': {'nickname': '탭 검증'},
      };
    } else if (options.path == '/me/library/summary') {
      body = {
        'is_success': true,
        'result': {
          'completed_count': 0,
          'reading_count': 0,
          'total_read_minutes': 0,
        },
      };
    } else {
      return super.fetch(options, requestStream, cancelFuture);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _Routes extends NavigatorObserver {
  final active = <Route<dynamic>>[];
  int replacements = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    active.add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    active[active.indexOf(oldRoute!)] = newRoute!;
    replacements++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    active.remove(route);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async =>
              call.method == 'read' &&
                  (call.arguments as Map)['key'] == 'access_token'
              ? 'fixture-access-token'
              : null,
        );
  });

  setUp(() {
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.httpClientAdapter = _TabApi();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: sibling tabs switch immediately without stacking', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigator = GlobalKey<NavigatorState>();
      final routes = _Routes();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          navigatorKey: navigator,
          navigatorObservers: [routes],
          home: const CelebritiesPage(),
        ),
      );
      await tester.pumpAndSettle();

      const pages = [CelebritiesPage, MyLibraryPage, TopicsPage];
      const icons = [Icons.people, Icons.menu_book, Icons.topic];
      for (final index in [1, 2, 0, 2, 1, 0]) {
        final previous = tester.state(
          find.byType(
            pages[tester
                .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
                .currentIndex],
          ),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(icons[index]),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        // Check before the normal platform page animation could have finished.
        expect(
          tester.getTopLeft(find.byType(pages[index])).dx,
          closeTo(0, .01),
        );
        expect(previous.mounted, isFalse);
        expect(routes.active, hasLength(1));
        expect(navigator.currentState!.canPop(), isFalse);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          index,
        );
        expect(tester.takeException(), isNull);
      }

      expect(routes.replacements, 6);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.people),
        ),
      );
      await tester.pumpAndSettle();
      expect(routes.replacements, 6);

      await tester.tap(find.text('첫 인물'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(CelebritiesBookPage), findsOneWidget);
      expect(routes.active, hasLength(2));
      expect(
        (routes.active.last as TransitionRoute<dynamic>).animation!.value,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(CelebritiesPage), findsOneWidget);
      expect(routes.active, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
