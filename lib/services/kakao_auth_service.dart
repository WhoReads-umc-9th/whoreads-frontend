import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../core/auth/token_storage.dart';
import '../core/network/api_client.dart';
import '../screens/auth/kakao_login_page.dart';
import 'kakao_oauth_session.dart';
import 'notification/fcm_service.dart';

/// 카카오 로그인 결과 상태
enum KakaoLoginStatus {
  /// 기존 회원 → 토큰까지 저장 완료, 바로 메인 진입 가능
  loggedIn,

  /// 신규 회원 → registrationToken 으로 추가 정보(닉네임/성별/연령) 입력 필요
  needsSignup,

  /// 실패 (사용자 취소 포함)
  failed,
}

class KakaoLoginResult {
  final KakaoLoginStatus status;

  /// 신규 회원일 때 카카오 회원가입에 사용할 임시 토큰
  final String? registrationToken;

  /// 카카오 계정에서 받아온 닉네임(입력 화면 프리필용)
  final String? nickname;

  /// 실패 시 사용자에게 보여줄 메시지
  final String? errorMessage;

  const KakaoLoginResult({
    required this.status,
    this.registrationToken,
    this.nickname,
    this.errorMessage,
  });
}

class KakaoAuthService {
  final Future<KakaoOAuthCallback?> Function(BuildContext, KakaoOAuthSession)
  _authorize;

  KakaoAuthService({
    Future<KakaoOAuthCallback?> Function(BuildContext, KakaoOAuthSession)?
    authorize,
  }) : _authorize = authorize ?? _openLoginPage;

  /// 모바일 카카오계정 REST 인증 → 서버 콜백 → 앱 로그인/가입.
  Future<KakaoLoginResult> login(BuildContext context) async {
    if (kIsWeb) return _loginWithSdk();
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return const KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: '카카오 로그인은 Android/iOS 앱에서 이용할 수 있습니다.',
      );
    }
    try {
      final session = KakaoOAuthSession.fromEnvironment(
        apiBaseUrl: ApiClient.baseUrl,
      );
      final callback = await _authorize(context, session);
      if (callback?.code == null) {
        return KakaoLoginResult(
          status: KakaoLoginStatus.failed,
          errorMessage: callback?.errorMessage,
        );
      }
      return loginWithAuthorizationCode(callback!.code!);
    } on FormatException catch (error) {
      return KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: error.message.toString(),
      );
    } catch (_) {
      return const KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: '카카오 로그인에 실패했습니다.',
      );
    }
  }

  static Future<KakaoOAuthCallback?> _openLoginPage(
    BuildContext context,
    KakaoOAuthSession session,
  ) => Navigator.of(context).push<KakaoOAuthCallback>(
    MaterialPageRoute(builder: (_) => KakaoLoginPage(session: session)),
  );

  /// 카카오톡/카카오계정으로 로그인 → 백엔드에 access_token 전달.
  /// 기존 회원이면 토큰 저장, 신규 회원이면 registrationToken 반환.
  Future<KakaoLoginResult> _loginWithSdk() async {
    // 1. 카카오 SDK 로그인 → 카카오 access_token 확보
    final String kakaoAccessToken;
    try {
      final OAuthToken token = await _loginWithKakao();
      kakaoAccessToken = token.accessToken;
    } catch (e) {
      debugPrint('카카오 SDK 로그인 실패: $e');
      // 사용자가 로그인 창을 닫은 경우 등
      if (e is KakaoAuthException || e is PlatformException) {
        return const KakaoLoginResult(status: KakaoLoginStatus.failed);
      }
      return const KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: '카카오 로그인에 실패했습니다.',
      );
    }

    // 2. 백엔드에 카카오 access_token 전달
    try {
      final response = await ApiClient.dio.post(
        '/auth/kakao/login/token',
        data: {'access_token': kakaoAccessToken},
      );
      return await _completeLogin(response);
    } catch (_) {
      return const KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: '서버와 통신할 수 없습니다.',
      );
    }
  }

  /// REST 인가 코드를 서버 콜백으로 전달한다.
  /// SDK access_token은 code로 사용할 수 없다. 호출자는 REST 방식으로 발급된
  /// 미사용 코드를 전달해야 하며, 브라우저가 이미 콜백을 호출했다면 재호출하면 안 된다.
  Future<KakaoLoginResult> loginWithAuthorizationCode(String code) async {
    if (code.trim().isEmpty) {
      return const KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: '카카오 로그인 인증 코드가 없습니다.',
      );
    }
    try {
      final response = await ApiClient.dio.get(
        '/auth/kakao/callback',
        queryParameters: {'code': code},
      );
      return await _completeLogin(response);
    } catch (_) {
      // 인가 코드나 토큰이 포함된 요청 URL을 로그에 남기지 않는다.
      return const KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: '서버와 통신할 수 없습니다.',
      );
    }
  }

  Future<KakaoLoginResult> _completeLogin(Response<dynamic> response) async {
    final decoded = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;

    final bool ok =
        (response.statusCode == 200 || response.statusCode == 201) &&
        !(decoded is Map && decoded['is_success'] == false);

    if (!ok || decoded is! Map || decoded['result'] is! Map) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      return KakaoLoginResult(
        status: KakaoLoginStatus.failed,
        errorMessage: message ?? '카카오 로그인에 실패했습니다.',
      );
    }

    final result = decoded['result'] as Map;
    final bool isNewMember = result['is_new_member'] == true;

    if (isNewMember) {
      final registrationToken = result['registration_token']?.toString();
      if (registrationToken == null || registrationToken.trim().isEmpty) {
        return const KakaoLoginResult(
          status: KakaoLoginStatus.failed,
          errorMessage: '가입 정보가 없습니다. 카카오 로그인을 다시 시도해주세요.',
        );
      }
      return KakaoLoginResult(
        status: KakaoLoginStatus.needsSignup,
        registrationToken: registrationToken,
        nickname: result['nickname']?.toString(),
      );
    }

    // 기존 회원 → 토큰 저장
    final tokenData = result['token_data'];
    if (result['is_new_member'] == false &&
        tokenData is Map &&
        tokenData['access_token'] is String &&
        (tokenData['access_token'] as String).trim().isNotEmpty) {
      await TokenStorage.saveTokens(
        accessToken: tokenData['access_token'].toString(),
        refreshToken: tokenData['refresh_token']?.toString(),
      );
      await _trySendFcmToken();
      return const KakaoLoginResult(status: KakaoLoginStatus.loggedIn);
    }

    return const KakaoLoginResult(
      status: KakaoLoginStatus.failed,
      errorMessage: '로그인 응답에 토큰이 없습니다.',
    );
  }

  /// 카카오 신규 회원가입 (registrationToken + 추가 정보) → 성공 시 토큰 저장.
  /// 성공하면 null, 실패하면 사용자에게 보여줄 메시지를 반환.
  Future<String?> signup({
    required String registrationToken,
    required String nickname,
    required String gender,
    required String ageGroup,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/auth/kakao/signup',
        data: {
          'registration_token': registrationToken,
          'nickname': nickname,
          'gender': gender,
          'age_group': ageGroup,
        },
      );

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      final bool ok =
          (response.statusCode == 200 || response.statusCode == 201) &&
          !(decoded is Map && decoded['is_success'] == false);

      if (!ok || decoded is! Map || decoded['result'] == null) {
        final message = decoded is Map ? decoded['message']?.toString() : null;
        return message ?? '회원가입에 실패했습니다.';
      }

      final result = decoded['result'] as Map;
      final accessToken = result['access_token'];
      if (accessToken == null) {
        return '회원가입 응답에 토큰이 없습니다.';
      }

      await TokenStorage.saveTokens(
        accessToken: accessToken.toString(),
        refreshToken: result['refresh_token']?.toString(),
      );
      await _trySendFcmToken();
      return null;
    } catch (e) {
      debugPrint('카카오 회원가입 API 에러: $e');
      return '회원가입 중 오류가 발생했습니다.';
    }
  }

  /// 카카오톡 설치 시 앱으로, 아니면 카카오계정(웹)으로 로그인
  Future<OAuthToken> _loginWithKakao() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        // 카카오톡 로그인 실패 시(취소 제외) 계정 로그인으로 폴백
        if (e is PlatformException && e.code == 'CANCELED') {
          rethrow;
        }
        return await UserApi.instance.loginWithKakaoAccount();
      }
    }
    return await UserApi.instance.loginWithKakaoAccount();
  }

  Future<void> _trySendFcmToken() async {
    try {
      await FcmService.sendTokenToServer();
    } catch (e) {
      debugPrint('⚠️ FCM 토큰 전송 실패(로그인은 유지): $e');
    }
  }
}
