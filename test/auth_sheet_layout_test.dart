import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/widgets/auth/login_method_sheet.dart';
import 'package:whoreads/widgets/auth/signup_terms_sheet.dart';

Future<GlobalKey> openSheet(
  WidgetTester tester, {
  required Size size,
  required double top,
  required double bottom,
  required bool login,
  double textScale = 1,
  VoidCallback? onKakao,
  VoidCallback? onEmail,
  VoidCallback? onAgreed,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: Colors.orange,
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => login
                    ? LoginMethodSheet(
                        onKakaoLogin: onKakao ?? () {},
                        onEmailLogin: onEmail ?? () {},
                      )
                    : SignupTermsSheet(onAgreed: onAgreed ?? () {}),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return boundaryKey;
}

void main() {
  const devices = [
    (name: 'iPhone SE', size: Size(375, 667), top: 20.0, bottom: 0.0),
    (name: 'small Android', size: Size(320, 568), top: 24.0, bottom: 24.0),
    (name: 'iPhone 16e', size: Size(390, 844), top: 47.0, bottom: 34.0),
    (name: 'iPhone 16', size: Size(393, 852), top: 62.0, bottom: 34.0),
    (name: 'large iPhone', size: Size(440, 956), top: 62.0, bottom: 34.0),
  ];
  for (final device in devices) {
    for (final login in [true, false]) {
      testWidgets(
        '${device.name}: ${login ? 'login' : 'terms'} fills the bottom safe area',
        (tester) async {
          final boundaryKey = await openSheet(
            tester,
            size: device.size,
            top: device.top,
            bottom: device.bottom,
            login: login,
          );
          expect(tester.takeException(), isNull);
          final button = login
              ? find
                    .ancestor(
                      of: find.text('아이디로 로그인'),
                      matching: find.byType(InkWell),
                    )
                    .first
              : find.byType(FilledButton);
          final bottom = tester.getBottomRight(button).dy;
          expect(bottom, lessThanOrEqualTo(device.size.height - device.bottom));
          expect(
            device.size.height - device.bottom - bottom,
            lessThanOrEqualTo(24),
          );

          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final bottomPixel = await tester.runAsync(() async {
            final image = await boundary.toImage();
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset =
                ((device.size.height.toInt() - 2) * image.width +
                    device.size.width ~/ 2) *
                4;
            final pixel = [
              pixels.getUint8(offset),
              pixels.getUint8(offset + 1),
              pixels.getUint8(offset + 2),
            ];
            image.dispose();
            return pixel;
          });
          expect(bottomPixel, [255, 255, 255]);
        },
      );
    }
  }

  for (final compactHeight in [false, true]) {
    for (final login in [true, false]) {
      testWidgets(
        '${login ? 'Login' : 'Terms'} remains usable with ${compactHeight ? 'limited height' : 'large text'}',
        (tester) async {
          var kakaoTaps = 0;
          var emailTaps = 0;
          var agreedTaps = 0;
          await openSheet(
            tester,
            size: compactHeight ? const Size(393, 320) : const Size(320, 568),
            top: compactHeight ? 62 : 24,
            bottom: 34,
            login: login,
            textScale: compactHeight ? 1.3 : 2,
            onKakao: () => kakaoTaps++,
            onEmail: () => emailTaps++,
            onAgreed: () => agreedTaps++,
          );
          expect(tester.takeException(), isNull);
          if (login) {
            await tester.ensureVisible(find.text('카카오로 로그인'));
            await tester.tap(find.text('카카오로 로그인'));
            await tester.ensureVisible(find.text('아이디로 로그인'));
            await tester.tap(find.text('아이디로 로그인'));
            expect(kakaoTaps, 1);
            expect(emailTaps, 1);
          } else {
            await tester.tap(find.byIcon(Icons.check).first);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('다음'));
            await tester.tap(find.text('다음'));
            expect(agreedTaps, 1);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
