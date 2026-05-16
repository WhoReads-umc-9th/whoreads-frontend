import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/token_storage.dart';

class ApiClient {
  static String baseUrl = '${dotenv.env['BASE_URL']}/api';

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 5),
            validateStatus: (status) => status != null && status < 600,
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
