// Uses the production auth interceptor and storage with a loopback API.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/auth/token_storage.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = <String, String>{};
  final requests = <String>[];
  late HttpServer server;
  HttpOverrides? previousOverrides;
  var rejectAccess = false;
  var serverFailure = false;
  setUpAll(() async {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.testLoad(fileInput: 'BASE_URL=http://127.0.0.1:${server.port}');
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
              case 'delete':
                tokens.remove(args!['key']);
              case 'deleteAll':
                tokens.clear();
            }
            return null;
          },
        );
    server.listen((request) async {
      requests.add(request.uri.path);
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      if (serverFailure) {
        request.response.statusCode = 503;
        request.response.write('{"is_success":false}');
      } else if (rejectAccess ||
          request.headers.value('authorization') != 'Bearer signup-access') {
        request.response.statusCode = 401;
        request.response.write('{"is_success":false}');
      } else {
        request.response.write(
          jsonEncode({
            'is_success': true,
            'result': {'nickname': '독자'},
          }),
        );
      }
      await request.response.close();
    });
  });
  tearDownAll(() async {
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  setUp(() {
    tokens.clear();
    requests.clear();
    rejectAccess = false;
    serverFailure = false;
  });
  test(
    'Valid signup access token survives startup without a refresh token',
    () async {
      await TokenStorage.saveTokens(accessToken: 'signup-access');
      expect(await AuthService().getLoggedIn(), isTrue);
      for (final path in [
        '/quotes/celebrities/1',
        '/members/follow/1',
        '/me/library/list',
      ]) {
        expect((await ApiClient.dio.get(path)).statusCode, 200);
      }
      expect(tokens['access_token'], 'signup-access');
      expect(requests, isNot(contains('/api/auth/refresh')));
    },
  );
  test(
    'Signup replaces the old refresh token instead of mixing accounts',
    () async {
      tokens.addAll({
        'access_token': 'old-access',
        'refresh_token': 'old-refresh',
      });
      await TokenStorage.saveTokens(accessToken: 'signup-access');
      expect(tokens, {'access_token': 'signup-access'});
    },
  );
  test('Expired access-only signup session requires login', () async {
    await TokenStorage.saveTokens(accessToken: 'signup-access');
    rejectAccess = true;
    expect(await AuthService().getLoggedIn(), isFalse);
    expect(tokens, isEmpty);
  });
  test('Server outage retains the access-only signup session', () async {
    await TokenStorage.saveTokens(accessToken: 'signup-access');
    serverFailure = true;
    expect(await AuthService().getLoggedIn(), isTrue);
    expect(tokens['access_token'], 'signup-access');
  });
  test('No saved session does not request the profile or refresh', () async {
    expect(await AuthService().getLoggedIn(), isFalse);
    expect(requests, isEmpty);
  });
}
