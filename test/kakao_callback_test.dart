import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/services/kakao_auth_service.dart';
import 'package:whoreads/services/kakao_oauth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = <String, String>{};
  final requests = <RequestOptions>[];
  final service = KakaoAuthService();
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = call.arguments as Map?;
          if (call.method == 'write') {
            tokens[args!['key'] as String] = args['value'] as String;
          }
          return null;
        });
  });

  setUp(() {
    dotenv.testLoad(
      fileInput:
          'BASE_URL=https://example.invalid\n'
          'KAKAO_REST_API_KEY=0123456789abcdef0123456789abcdef',
    );
    tokens.clear();
    requests.clear();
    ApiClient.dio.interceptors.clear();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  void respond(Object data, {int status = 200}) {
    ApiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(requestOptions: options, statusCode: status, data: data),
          );
        },
      ),
    );
  }

  testWidgets(
    '모바일 로그인 진입이 REST 인가 후 콜백을 한 번만 호출한다',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      KakaoOAuthSession? requestedSession;
      final restService = KakaoAuthService(
        authorize: (_, session) async {
          requestedSession = session;
          return session.parseCallback(
            session.redirectUri.replace(
              queryParameters: {
                'code': 'test-rest-code',
                'state': session.state,
              },
            ),
          );
        },
      );
      respond({
        'is_success': true,
        'result': {
          'is_new_member': false,
          'token_data': {'access_token': 'test-rest-access'},
        },
      });
      final result = await tester.runAsync(() => restService.login(context));
      expect(result!.status, KakaoLoginStatus.loggedIn);
      expect(requestedSession!.authorizationUri.host, 'kauth.kakao.com');
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.uri.path, '/api/auth/kakao/callback');
      expect(requests.single.uri.queryParameters['code'], 'test-rest-code');
      expect(tokens['access_token'], 'test-rest-access');
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    '로그인 창 취소 또는 잘못된 state는 서버 호출 없이 종료한다',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final canceled in [true, false]) {
        final restService = KakaoAuthService(
          authorize: (_, session) async {
            if (canceled) return null;
            return session.parseCallback(
              session.redirectUri.replace(
                queryParameters: {'code': 'test-code', 'state': 'wrong-state'},
              ),
            );
          },
        );
        final result = await restService.login(context);
        expect(result.status, KakaoLoginStatus.failed);
        expect(result.errorMessage, canceled ? isNull : isNotNull);
        expect(requests, isEmpty);
        expect(tokens, isEmpty);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  test('인가 코드를 GET 콜백에 전달하고 기존 회원 토큰을 저장한다', () async {
    respond({
      'is_success': true,
      'result': {
        'is_new_member': false,
        'token_data': {
          'access_token': 'test-access',
          'refresh_token': 'test-refresh',
        },
      },
    });
    final result = await service.loginWithAuthorizationCode('test-code+&=');

    expect(result.status, KakaoLoginStatus.loggedIn);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.uri.path, '/api/auth/kakao/callback');
    expect(requests.single.uri.queryParameters['code'], 'test-code+&=');
    expect(requests.single.data, isNull);
    expect(tokens['access_token'], 'test-access');
    expect(tokens['refresh_token'], 'test-refresh');
  });

  test('신규 회원 JSON은 가입 정보 입력에 필요한 임시 토큰을 반환한다', () async {
    respond(
      jsonEncode({
        'is_success': true,
        'result': {
          'is_new_member': true,
          'registration_token': 'test-registration',
          'nickname': '독자',
        },
      }),
    );
    final result = await service.loginWithAuthorizationCode('test-code');

    expect(result.status, KakaoLoginStatus.needsSignup);
    expect(result.registrationToken, 'test-registration');
    expect(result.nickname, '독자');
    expect(tokens, isEmpty);
  });

  test('빈 인가 코드로 서버를 호출하지 않는다', () async {
    final result = await service.loginWithAuthorizationCode('  ');
    expect(result.status, KakaoLoginStatus.failed);
    expect(requests, isEmpty);
    expect(tokens, isEmpty);
  });

  test('실패한 콜백은 재시도하지 않고 서버 오류를 반환한다', () async {
    respond({'is_success': false, 'message': '인증 코드가 만료되었습니다.'}, status: 400);
    final result = await service.loginWithAuthorizationCode(
      'expired-test-code',
    );
    expect(result.status, KakaoLoginStatus.failed);
    expect(result.errorMessage, '인증 코드가 만료되었습니다.');
    expect(requests, hasLength(1));
    expect(tokens, isEmpty);
  });

  for (final result in <Object?>[
    null,
    'invalid-result',
    {'is_new_member': true},
    {
      'is_new_member': false,
      'token_data': {'access_token': ''},
    },
    {
      'token_data': {'access_token': 'test-access'},
    },
  ]) {
    test('불완전한 콜백 결과로 로그인을 완료하지 않는다: $result', () async {
      respond({'is_success': true, 'result': result});
      final login = await service.loginWithAuthorizationCode('test-code');
      expect(login.status, KakaoLoginStatus.failed);
      expect(tokens, isEmpty);
    });
  }
}
