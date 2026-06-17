import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/token_storage.dart';
import '../../core/router/app_router.dart';

class ApiClient {
  static String baseUrl = '${dotenv.env['BASE_URL']}/api';

  static final Dio _refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

  static final Dio _dio = Dio(
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
  )..interceptors.addAll([
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await TokenStorage.getAccessToken();
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        debugPrint('Request: ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        if (response.statusCode == 401) {
          final options = response.requestOptions;

          final bool isRefreshed = await attemptTokenRefresh();

          if (isRefreshed) {
            final newAccessToken = await TokenStorage.getAccessToken();
            options.headers['Authorization'] = 'Bearer $newAccessToken';

            try {
              final clonedResponse = await _dio.fetch(options);
              return handler.resolve(clonedResponse);
            } on DioException catch (e) {
              return handler.reject(e);
            }
          } else {
            debugPrint('토큰 재발급 실패');

            AppRouter.navigateAndRemoveUntil('/');

            return handler.next(response);
          }
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
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

  static Dio get dio => _dio;

  static Future<bool> attemptTokenRefresh() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null) {
        await TokenStorage.clear();
        return false;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newAccessToken = response.data['result']['access_token'];
        final newRefreshToken = response.data['result']['refresh_token'];

        if (newAccessToken != null && newRefreshToken != null) {
          await TokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          debugPrint('토큰 재발급 성공');
          return true;
        }
      }

      await TokenStorage.clear();
      return false;
    } catch (e) {
      debugPrint('토큰 재발급 중 예외 발생: $e');
      await TokenStorage.clear();
      return false;
    }
  }
}