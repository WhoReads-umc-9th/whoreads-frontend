import 'dart:convert';
import 'dart:math';

class KakaoOAuthCallback {
  final String? code;
  final String? errorMessage;

  const KakaoOAuthCallback({this.code, this.errorMessage});
}

/// 한 번의 REST 로그인 요청과 해당 요청의 콜백을 묶는다.
class KakaoOAuthSession {
  final Uri redirectUri;
  final String state;

  KakaoOAuthSession({required this.redirectUri, String? state})
    : state = state ?? _createState();

  factory KakaoOAuthSession.forBackend({required String apiBaseUrl}) {
    final backendCallback = Uri.parse('$apiBaseUrl/auth/kakao/callback');
    if (backendCallback.scheme != 'https' ||
        backendCallback.host.isEmpty ||
        backendCallback.userInfo.isNotEmpty ||
        backendCallback.hasQuery ||
        backendCallback.hasFragment) {
      throw const FormatException('카카오 로그인 서버 주소가 올바르지 않습니다.');
    }
    return KakaoOAuthSession(redirectUri: backendCallback);
  }

  // 서버가 REST 키와 고정 redirect_uri로 카카오 인가 주소를 생성한다.
  Uri get authorizationUri => redirectUri.replace(
    path: redirectUri.path.replaceFirst(RegExp(r'/callback$'), '/authorize'),
    queryParameters: {'state': state},
  );

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
