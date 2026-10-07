import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/services/kakao_auth_service.dart';

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
