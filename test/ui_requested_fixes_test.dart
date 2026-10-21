import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/auth/find_account_page.dart';
import 'package:whoreads/screens/auth/login_page.dart';
import 'package:whoreads/screens/auth/reset_password_page.dart';
import 'package:whoreads/screens/celebrities/celebrities_book_page.dart';
import 'package:whoreads/screens/celebrities/celebrities_page.dart';
import 'package:whoreads/screens/topics/topics_page.dart';
import 'package:whoreads/widgets/common/job_tag.dart';

import 'support/ui_fix_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UiFixApi api;
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  setUp(() {
    api = UiFixApi();
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.httpClientAdapter = api;
  });

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    double width = 393,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
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

  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Login recovery rows are centered at $width / $scale', (
        tester,
      ) async {
        await show(tester, const LoginPage(), width: width, scale: scale);
        for (final text in ['비밀번호를 잊으셨나요?', '계정이 기억나지 않나요?']) {
          final row = find
              .ancestor(of: find.text(text), matching: find.byType(Wrap))
              .first;
          expect(tester.getRect(row).center.dx, closeTo(width / 2, 0.5));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('비밀번호 재설정'));
        await tester.pumpAndSettle();
        expect(find.byType(ResetPasswordPage), findsOneWidget);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('gmail.com'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField).first, 'layout');
        await tester.pump();
        await tester.tap(find.text('인증하기'));
        await tester.pumpAndSettle();
        expect(
          api.requests.any((request) => request.path == '/auth/email/send'),
          isTrue,
        );
        await tester.enterText(find.byType(TextField).last, '123456');
        await tester.pump();
        await tester.ensureVisible(find.text('확인'));
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        expect(find.text('새 비밀번호'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
        'Larger occupation tags wrap and neighboring cards align at $width / $scale',
        (tester) async {
          await show(
            tester,
            const CelebritiesPage(),
            width: width,
            scale: scale,
          );
          final firstTag = find.widgetWithText(JobTag, '스포츠선수');
          final secondTag = find.widgetWithText(JobTag, '뮤지컬배우');
          expect(
            tester.getRect(secondTag).top,
            greaterThanOrEqualTo(tester.getRect(firstTag).bottom),
          );
          expect(
            tester.widget<Text>(find.text('스포츠선수').first).style!.fontSize,
            12,
          );
          expect(
            tester.getTopLeft(find.text('첫 인물')).dy,
            tester.getTopLeft(find.text('둘째 인물')).dy,
          );
          final badges = [firstTag, secondTag];
          final tile = tester.getRect(
            find
                .ancestor(of: firstTag, matching: find.byType(GestureDetector))
                .first,
          );
          for (final tag in badges) {
            expect(tester.getRect(tag).left, greaterThanOrEqualTo(tile.left));
            expect(
              tester.getRect(tag).right,
              lessThanOrEqualTo(tile.right + 0.1),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'All remains the first category after server categories load and clears filtering',
    (tester) async {
      await show(tester, const CelebritiesPage());
      await tester.tap(find.text('카테고리'));
      await tester.pumpAndSettle();
      var menu = find.byKey(const ValueKey('celebrities-category-menu'));
      final options = tester
          .widgetList<Text>(
            find.descendant(of: menu, matching: find.byType(Text)),
          )
          .map((text) => text.data)
          .toList();
      expect(options.first, '전체');
      await tester.tap(find.descendant(of: menu, matching: find.text('가수')));
      await tester.pumpAndSettle();
      expect(find.text('첫 인물'), findsNothing);
      expect(
        api.requests.lastWhere((r) => r.path == '/celebrities').queryParameters,
        {'tag': 'SINGER'},
      );
      await tester.tap(find.text('카테고리'));
      await tester.pumpAndSettle();
      menu = find.byKey(const ValueKey('celebrities-category-menu'));
      await tester.tap(find.descendant(of: menu, matching: find.text('전체')));
      await tester.pumpAndSettle();
      expect(
        api.requests
            .lastWhere((r) => r.path == '/celebrities')
            .queryParameters
            .containsKey('tag'),
        isFalse,
      );
      expect(find.text('첫 인물'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Occupation colors agree between celebrity cards and their actual detail screen',
    (tester) async {
      await show(tester, const CelebritiesPage());
      final badge = find.widgetWithText(JobTag, '스포츠선수');
      Color background(Finder tag) =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: tag,
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      final listColor = background(badge);
      await tester.tap(find.text('첫 인물'));
      await tester.pumpAndSettle();
      expect(find.byType(CelebritiesBookPage), findsOneWidget);
      expect(background(find.widgetWithText(JobTag, '스포츠선수').last), listColor);
      expect(
        background(find.widgetWithText(JobTag, '뮤지컬배우').last),
        JobTag.colorFor('뮤지컬배우'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A slow previous filter cannot replace the restored All list', (
    tester,
  ) async {
    final pending = Completer<void>();
    api.beforeResponse = (request) async {
      if (request.path == '/celebrities' &&
          request.queryParameters['tag'] == 'SINGER') {
        await pending.future;
      }
    };
    await show(tester, const CelebritiesPage());
    final menu = find.byKey(const ValueKey('celebrities-category-menu'));
    await tester.tap(find.text('카테고리'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: menu, matching: find.text('가수')));
    await tester.pump();
    await tester.tap(find.text('카테고리'));
    await tester.pump();
    await tester.tap(find.descendant(of: menu, matching: find.text('전체')));
    await tester.pumpAndSettle();
    expect(find.text('첫 인물'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('첫 인물'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 393.0]) {
    testWidgets(
      'Topics category bar pins and opens directly below its anchor at $width',
      (tester) async {
        await show(tester, const TopicsPage(), width: width);
        final bar = find.byKey(const ValueKey('topics-category-bar'));
        final appBar = find.byType(AppBar);
        expect(
          tester.getTopLeft(bar).dy,
          greaterThan(tester.getBottomRight(appBar).dy + 100),
        );
        await tester.tap(find.text('카테고리'));
        await tester.pumpAndSettle();
        final menu = find.byKey(const ValueKey('topics-category-menu'));
        expect(
          tester.getTopLeft(menu).dy,
          closeTo(tester.getBottomRight(bar).dy, 1),
        );
        await tester.tap(find.descendant(of: menu, matching: find.text('과학')));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(bar).dy,
          closeTo(tester.getBottomRight(appBar).dy, 1),
        );
        expect(
          tester.getTopLeft(find.byType(GridView)).dy,
          closeTo(tester.getBottomRight(bar).dy + 16, 1),
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(bar).dy,
          closeTo(tester.getBottomRight(appBar).dy, 1),
        );
        await tester.tap(find.text('카테고리'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(menu).dy,
          closeTo(tester.getBottomRight(bar).dy, 1),
        );
        await tester.tap(find.descendant(of: menu, matching: find.text('문학')));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byType(GridView)).dy,
          closeTo(tester.getBottomRight(bar).dy + 16, 1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Account recovery screen is reachable and does not overflow a small phone',
    (tester) async {
      await show(tester, const LoginPage(), width: 320);
      await tester.tap(find.text('계정 찾기'));
      await tester.pumpAndSettle();
      expect(find.byType(FindAccountPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
