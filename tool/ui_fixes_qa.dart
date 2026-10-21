// Simulator-only entry point for reproducing the UI checks with local fixtures.
// flutter run -t tool/ui_fixes_qa.dart -d <simulator-id>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/screens/auth/login_page.dart';
import 'package:whoreads/screens/celebrities/celebrities_page.dart';
import 'package:whoreads/screens/topics/topics_page.dart';

import '../test/support/ui_fix_fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final image = await rootBundle.load('assets/images/person.png');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.headers.contentType = ContentType('image', 'png');
    request.response.add(
      image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes),
    );
    await request.response.close();
  });
  ApiClient.dio.interceptors.clear();
  ApiClient.dio.httpClientAdapter = UiFixApi(
    imageUrl: 'http://127.0.0.1:${server.port}/person.png',
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('로컬 UI 검증')),
        body: Builder(
          builder: (context) => Column(
            children: [
              for (final entry in <String, Widget>{
                '로그인 화면': const LoginPage(),
                '인물 화면': const CelebritiesPage(),
                '주제 화면': const TopicsPage(),
              }.entries)
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => entry.value)),
                  child: Text(entry.key),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
