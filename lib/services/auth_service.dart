import 'notification/fcm_service.dart';
import 'timer/timer_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:whoreads/core/auth/token_storage.dart';
import 'package:whoreads/core/network/api_client.dart';

class AuthService {
  Future<void> logout() async {
    try {
      await ApiClient.dio.post("/auth/logout");
    } catch (e) {
      debugPrint("서버 로그아웃 요청 실패");
    } finally {
      await TokenStorage.clear();
      try {
        await TimerService().discardLocalSession();
      } catch (_) {}
      await FcmService.clearSession();
    }
  }

  Future<bool> getLoggedIn() async {
    try {
      final token = await TokenStorage.getAccessToken();

      if (token == null || token.isEmpty) return false;

      // Email signup currently returns an access token without a refresh token.
      // Validate that session first; ApiClient refreshes only after a real 401.
      final response = await ApiClient.dio.get('/members/me');
      if (response.statusCode == 401) {
        await TokenStorage.clear();
        return false;
      }
      ApiClient.requireSuccess(response);
      return true;
    } catch (e) {
      return (await TokenStorage.getAccessToken())?.isNotEmpty == true;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final response = await ApiClient.dio.patch("/auth/delete");
      if (response.statusCode == 200 || response.statusCode == 204) {
        await TokenStorage.clear();
        try {
          await TimerService().discardLocalSession();
        } catch (_) {}
        await FcmService.clearSession();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("회원탈퇴 실패: $e");
      return false;
    }
  }
}
