import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/auth/token_storage.dart';

class ApiClient {
  static String baseUrl = 'http://192.168.35.89:8080/api';

  static final Dio _dio =
      Dio(
          BaseOptions(
            // 실제에서 env로 빼야 됨
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 5),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
          ),
        )
        ..interceptors.addAll([
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final accessToken = await TokenStorage.getAccessToken();
              if (accessToken != null) {
                options.headers['Authorization'] = 'Bearer $accessToken';
              }
              debugPrint('Request: ${options.method} ${options.path}');
              return handler.next(options);
            },
          ),
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            requestHeader: true,
            responseHeader: true,
            error: true,
          ),
        ]);

  //static으로 접근 가능하게 함
  static Dio get dio => _dio;
}
