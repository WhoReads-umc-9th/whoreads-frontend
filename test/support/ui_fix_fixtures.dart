import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Local UI fixtures only. No authentication or production writes are performed.
class UiFixApi implements HttpClientAdapter {
  UiFixApi({this.imageUrl = ''});

  final String imageUrl;
  final requests = <RequestOptions>[];
  Future<void> Function(RequestOptions)? beforeResponse;

  List<Map<String, Object>> get people => [
    for (var i = 1; i <= 24; i++)
      {
        'id': i,
        'name': i == 1
            ? '첫 인물'
            : i == 2
            ? '둘째 인물'
            : '인물 $i',
        'image_url': imageUrl,
        'job_tags': i == 1
            ? ['스포츠선수', '뮤지컬배우']
            : i == 2
            ? ['가수']
            : ['배우', '작가'],
        'bio': '화면 배치 확인용 로컬 데이터입니다.',
      },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await beforeResponse?.call(options);
    final Object body;
    switch (options.path) {
      case '/celebrities/categories':
        body = {
          'result': [
            {'name': '가수', 'code': 'SINGER'},
            {'name': '배우', 'code': 'ACTOR'},
            {'name': '스포츠선수', 'code': 'ATHLETE'},
          ],
        };
      case '/celebrities':
        body = {
          'result': options.queryParameters['tag'] == 'SINGER'
              ? [people[1]]
              : people,
        };
      case '/celebrities/1':
        body = people.first;
      case '/quotes/celebrities/1':
      case '/topics':
        body = <Object>[];
      case '/members/follow/1':
        body = {'result': false};
      case '/me/library/list':
        body = {
          'result': {'books': <Object>[]},
        };
      case '/books':
        body = {
          'has_next': false,
          'content': [
            for (var i = 1; i <= 30; i++)
              {
                'id': i,
                'title': '검증 도서 $i',
                'author_name': '저자 $i',
                'cover_url': imageUrl,
                'genre': i.isOdd ? '문학' : '과학·기술',
              },
          ],
        };
      default:
        body = {'is_success': true, 'result': true};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
