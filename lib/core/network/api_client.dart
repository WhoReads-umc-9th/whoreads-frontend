import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/token_storage.dart';
import '../router/app_router.dart';

class ApiClient {
  static String baseUrl = '${dotenv.env['BASE_URL']}/api';
  static Future<bool>? _refreshInFlight;
  static const _retried = 'authRetried';
  static final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 5),
            // Form screens inspect 4xx responses to show server validation messages.
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              try {
                if (!options.path.startsWith('/auth/')) {
                  final token = await TokenStorage.getAccessToken();
                  if (token != null)
                    options.headers['Authorization'] = 'Bearer $token';
                } else if (options.path == '/auth/logout' ||
                    options.path == '/auth/delete') {
                  final token = await TokenStorage.getAccessToken();
                  if (token != null)
                    options.headers['Authorization'] = 'Bearer $token';
                }
                handler.next(options);
              } catch (e) {
                handler.reject(DioException(requestOptions: options, error: e));
              }
            },
            onResponse: (response, handler) async {
              final options = response.requestOptions;
              if (response.statusCode != 401 ||
                  options.path.startsWith('/auth/')) {
                handler.next(response);
                return;
              }
              if (options.extra[_retried] == true) {
                await TokenStorage.clear();
                AppRouter.navigateAndRemoveUntil('/');
                handler.next(response);
                return;
              }
              try {
                final current = await TokenStorage.getAccessToken();
                final alreadyRefreshed =
                    current != null &&
                    options.headers['Authorization'] != 'Bearer $current';
                if (alreadyRefreshed || await attemptTokenRefresh()) {
                  options.extra[_retried] = true;
                  options.headers['Authorization'] =
                      'Bearer ${await TokenStorage.getAccessToken()}';
                  // An ordinary interceptor permits the retried response to complete.
                  handler.resolve(await _dio.fetch(options));
                } else {
                  AppRouter.navigateAndRemoveUntil('/');
                  handler.next(response);
                }
              } on DioException catch (e) {
                handler.reject(e);
              } catch (e) {
                handler.reject(DioException(requestOptions: options, error: e));
              }
            },
          ),
        );

  static Dio get dio => _dio;

  static Future<Response<T>> checked<T>(Future<Response<T>> request) async {
    final response = await request;
    requireSuccess(response);
    return response;
  }

  static void requireSuccess(Response response) {
    final status = response.statusCode ?? 0;
    if (status < 200 ||
        status >= 300 ||
        (response.data is Map && response.data['is_success'] == false)) {
      throw DioException.badResponse(
        statusCode: status,
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }

  static Future<bool> attemptTokenRefresh() async {
    if (_refreshInFlight != null) return _refreshInFlight!;
    final refresh = _refreshTokens();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  static Future<bool> _refreshTokens() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await TokenStorage.clear();
      return false;
    }
    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      requireSuccess(response);
      final result = response.data['result'];
      final access = result?['access_token'];
      final refresh = result?['refresh_token'];
      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty) {
        throw DioException(
          requestOptions: response.requestOptions,
          error: 'Invalid token refresh response',
        );
      }
      // Logout/account switching while a refresh was in flight must win.
      if (await TokenStorage.getRefreshToken() != refreshToken) return false;
      await TokenStorage.saveTokens(accessToken: access, refreshToken: refresh);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        if (await TokenStorage.getRefreshToken() == refreshToken) {
          await TokenStorage.clear();
        }
        return false;
      }
      // Connectivity and server failures are not evidence of an invalid session.
      rethrow;
    }
  }
}
