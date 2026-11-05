import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/celebrities/celebrities_page.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';
import 'package:whoreads/screens/topics/topics_page.dart';
import 'package:whoreads/widgets/common/job_tag.dart';

import 'support/ui_fix_fixtures.dart';

class _AppearanceApi extends UiFixApi {
  @override
  List<Map<String, Object>> get people => [
    for (var i = 1; i <= 25; i++)
      {
        'id': i,
        'name': '인물 $i',
        'image_url': '',
        'job_tags': switch (i % 3) {
          1 => ['물리학자', '과학커뮤니케이터'],
          2 => ['가수', '배우'],
          _ => <String>[],
        },
      },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body;
    switch (options.path) {
      case '/members/me':
        body = {
          'result': {'nickname': '화면 검증'},
        };
      case '/me/library/summary':
        body = {
          'is_success': true,
          'result': {
            'completed_count': 0,
            'reading_count': 0,
            'total_read_minutes': 0,
          },
        };
      case '/me/library/list':
        body = {
          'is_success': true,
          'result': {
            'books': [
              for (var i = 1; i <= 25; i++)
                {
                  'book': {'id': i, 'title': '검증 도서 $i', 'author_name': '저자'},
                },
            ],
          },
        };
      default:
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'read' ? 'fixture-access-token' : null,
        );
  });

  setUp(() {
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.httpClientAdapter = _AppearanceApi();
  });

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    double width = 360,
    double dpr = 3,
    double scale = 1,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = Size(width * dpr, 852 * dpr);
    tester.view.padding = FakeViewPadding(top: 24 * dpr, bottom: 34 * dpr);
    tester.view.viewPadding = tester.view.padding;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final page in [
      const CelebritiesPage(),
      const MyLibraryPage(),
      const TopicsPage(),
    ]) {
      testWidgets(
        '$platform ${page.runtimeType}: bars stay white after scrolling',
        (tester) async {
          await show(tester, page, platform: platform);
          final appBarMaterial = find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Material),
              )
              .first;
          final bottomNav = find.byType(BottomNavigationBar);
          final bottomRect = tester.getRect(bottomNav);
          for (var scroll = 0; scroll < 3; scroll++) {
            final bar = tester.widget<Material>(appBarMaterial);
            expect(bar.color, Colors.white);
            expect(bar.elevation, 0);
            expect(bar.surfaceTintColor, Colors.transparent);
            expect(
              tester
                  .widget<AppBar>(find.byType(AppBar))
                  .systemOverlayStyle!
                  .statusBarIconBrightness,
              Brightness.dark,
            );
            final nav = tester.widget<BottomNavigationBar>(bottomNav);
            expect(nav.backgroundColor, Colors.white);
            expect(nav.elevation, 0);
            expect(tester.getRect(bottomNav), bottomRect);
            expect(bottomRect.height, greaterThanOrEqualTo(56 + 34));
            final scrollable = find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      axisDirectionToAxis(widget.axisDirection) ==
                          Axis.vertical,
                )
                .first;
            await tester.drag(scrollable, const Offset(0, -240));
            await tester.pumpAndSettle();
            expect(
              tester.state<ScrollableState>(scrollable).position.pixels,
              greaterThan(0),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final (width, dpr) in [(320.0, 2.0), (360.0, 3.0), (393.0, 2.625)]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Tags fit rows at width=$width dpr=$dpr text=$scale', (
        tester,
      ) async {
        await show(
          tester,
          const CelebritiesPage(),
          width: width,
          dpr: dpr,
          scale: scale,
        );
        final firstCard = find
            .ancestor(
              of: find.text('인물 1'),
              matching: find.byType(GestureDetector),
            )
            .first;
        final firstRect = tester.getRect(firstCard);
        for (final tag in ['물리학자', '과학커뮤니케이터']) {
          final rect = tester.getRect(find.widgetWithText(JobTag, tag).first);
          expect(rect.bottom, lessThanOrEqualTo(firstRect.bottom + 0.01));
          expect(rect.left, greaterThanOrEqualTo(firstRect.left - 0.01));
          expect(rect.right, lessThanOrEqualTo(firstRect.right + 0.01));
        }
        final nextRow = find
            .ancestor(
              of: find.text('인물 4'),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(
          tester.getTopLeft(nextRow).dy,
          closeTo(firstRect.bottom + 24, 0.01),
        );
        await tester.scrollUntilVisible(find.text('인물 25'), 300);
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text('인물 25'),
                      matching: find.byType(GestureDetector),
                    )
                    .first,
              )
              .width,
          closeTo(firstRect.width, 0.01),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
