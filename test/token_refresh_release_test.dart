// Real production interceptor against a loopback HTTP server; fake tokens only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'AUTH: expired token request completes after successful refresh',
    () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        HttpOverrides.global = previousOverrides;
      });
      dotenv.testLoad(fileInput: 'BASE_URL=http://127.0.0.1:${server.port}');
      final tokens = {
        'access_token': 'expired-test',
        'refresh_token': 'refresh-test',
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async {
              final args = call.arguments as Map?;
              if (call.method == 'read') return tokens[args!['key']];
              if (call.method == 'write') tokens[args!['key']] = args['value'];
              if (call.method == 'deleteAll') tokens.clear();
              return null;
            },
          );
      final paths = <String>[];
      server.listen((req) async {
        paths.add(req.uri.path);
        await req.drain<void>();
        req.response.headers.contentType = ContentType.json;
        if (req.uri.path == '/api/auth/refresh') {
          req.response.write(
            jsonEncode({
              'result': {
                'access_token': 'fresh-test',
                'refresh_token': 'new-refresh-test',
              },
            }),
          );
        } else if (req.headers.value('authorization') == 'Bearer fresh-test') {
          req.response.write('{"is_success":true}');
        } else {
          req.response.statusCode = 401;
          req.response.write('{"is_success":false}');
        }
        await req.response.close();
      });
      try {
        final response = await ApiClient.dio
            .get('/protected')
            .timeout(const Duration(seconds: 3));
        expect(response.statusCode, 200);
      } on TimeoutException {
        fail(
          'Request stalled after successful refresh. Observed paths: $paths; '
          'new token saved: ${tokens['access_token'] == 'fresh-test'}',
        );
      }
    },
  );
}
