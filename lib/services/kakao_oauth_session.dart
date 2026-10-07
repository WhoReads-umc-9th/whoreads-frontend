import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class KakaoOAuthCallback {
  final String? code;
  final String? errorMessage;

  const KakaoOAuthCallback({this.code, this.errorMessage});
}

/// 한 번의 REST 로그인 요청과 해당 요청의 콜백을 묶는다.
class KakaoOAuthSession {
  final String restApiKey;
  final Uri redirectUri;
  final String state;

  KakaoOAuthSession({
    required this.restApiKey,
    required this.redirectUri,
    String? state,
  }) : state = state ?? _createState();

  factory KakaoOAuthSession.fromEnvironment({required String apiBaseUrl}) {
    final key = dotenv.isInitialized
        ? dotenv.env['KAKAO_REST_API_KEY']?.trim() ?? ''
        : '';
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(key)) {
      throw const FormatException('카카오 REST API 키가 설정되지 않았습니다.');
    }
    final backendCallback = Uri.parse('$apiBaseUrl/auth/kakao/callback');
    final configured = dotenv.isInitialized
        ? dotenv.env['KAKAO_REDIRECT_URI']?.trim()
        : null;
    final redirect = Uri.tryParse(
      configured?.isNotEmpty == true ? configured! : backendCallback.toString(),
    );
    // 인가 코드가 발급된 redirect_uri와 코드 교환 서버가 일치해야 한다.
    if (redirect == null ||
        redirect.scheme != 'https' ||
        redirect != backendCallback) {
      throw const FormatException('카카오 로그인 서버 주소가 올바르지 않습니다.');
    }
    return KakaoOAuthSession(restApiKey: key, redirectUri: redirect);
  }

  Uri get authorizationUri => Uri.https('kauth.kakao.com', '/oauth/authorize', {
    'client_id': restApiKey,
    'redirect_uri': redirectUri.toString(),
    'response_type': 'code',
    'state': state,
  });

  bool isCallback(Uri uri) =>
      uri.scheme == redirectUri.scheme &&
      uri.host == redirectUri.host &&
      uri.port == redirectUri.port &&
      uri.path == redirectUri.path &&
      uri.userInfo.isEmpty;

  KakaoOAuthCallback parseCallback(Uri uri) {
    const invalid = KakaoOAuthCallback(
      errorMessage: '카카오 로그인 응답이 올바르지 않습니다. 다시 시도해주세요.',
    );
    if (!isCallback(uri) || uri.hasFragment) return invalid;
    final params = uri.queryParametersAll;
    if (params['state']?.length != 1 || params['state']!.single != state) {
      return invalid;
    }
    if (params.containsKey('error')) {
      if (params['error']?.length != 1 || params.containsKey('code')) {
        return invalid;
      }
      return params['error']!.single == 'access_denied'
          ? const KakaoOAuthCallback()
          : const KakaoOAuthCallback(errorMessage: '카카오 인증에 실패했습니다.');
    }
    final codes = params['code'];
    if (codes?.length != 1 || codes!.single.trim().isEmpty) return invalid;
    return KakaoOAuthCallback(code: codes.single);
  }

  static String _createState() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }
}
