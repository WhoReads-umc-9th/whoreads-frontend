import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/router/app_router.dart';
import 'package:whoreads/services/notification/fcm_service.dart';

void main() {
  test('Push destinations accept JSON links and reject invalid IDs', () {
    expect(
      FcmService.destinationFor({
        'type': 'FOLLOW',
        'link': '{"celebrity_id":"42"}',
      })?.arguments,
      42,
    );
    expect(
      FcmService.destinationFor({'type': 'FOLLOW', 'celebrity_id': 42})?.route,
      '/celebrity/book',
    );
    expect(
      FcmService.destinationFor({'type': 'FOLLOW', 'link': 'invalid'}),
      isNull,
    );
    expect(
      FcmService.destinationFor({'type': 'FOLLOW', 'celebrity_id': -1}),
      isNull,
    );
    expect(FcmService.destinationFor({'type': 'ROUTINE'})?.route, '/library');
  });

  testWidgets(
    'Cold-start push waits for authenticated navigation and delivers once',
    (tester) async {
      String? token;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => token,
      );
      await FcmService.clearSession();
      await FcmService.handleNotificationData({
        'type': 'FOLLOW',
        'celebrity_id': 42,
      });
      var navigations = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AppRouter.navigatorKey,
          home: const Scaffold(body: Text('home')),
          onGenerateRoute: (settings) {
            navigations++;
            return MaterialPageRoute(
              settings: settings,
              builder: (_) =>
                  Scaffold(body: Text('celebrity ${settings.arguments}')),
            );
          },
        ),
      );
      await FcmService.authenticatedNavigatorReady();
      await tester.pumpAndSettle();
      expect(navigations, 0);
      token = 'test-access';
      await FcmService.authenticatedNavigatorReady();
      await tester.pumpAndSettle();
      expect(find.text('celebrity 42'), findsOneWidget);
      await FcmService.authenticatedNavigatorReady();
      expect(navigations, 1);
      await FcmService.clearSession();
    },
  );
}
