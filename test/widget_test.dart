import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/main.dart';
import 'package:whoreads/screens/onboarding/onboarding_flow_screen.dart';

void main() {
  testWidgets('First launch without tokens reaches onboarding', (tester) async {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    ApiClient.dio.interceptors.clear();
    ApiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'is_success': true},
          ),
        ),
      ),
    );
    await tester.pumpWidget(const WhoReadsApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlowScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
