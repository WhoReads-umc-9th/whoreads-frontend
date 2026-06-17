import 'package:flutter/cupertino.dart';
import 'package:whoreads/core/auth/token_storage.dart';
import 'package:whoreads/core/network/api_client.dart';

class AuthService {
  Future<void> logout() async {
    try {
      await ApiClient.dio.post("/auth/logout");
      await TokenStorage.clear();
    } catch (e) {
      debugPrint("로그아웃 실패");
    }
  }
  Future<bool> getLoggedIn() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final refreshToken = await TokenStorage.getRefreshToken();
      debugPrint("최초 확인된 토큰 존재 여부: ${refreshToken!= null}, $token,$refreshToken");

      if (token != null) {
        final bool isTokenValid = await ApiClient.attemptTokenRefresh();
        return isTokenValid;
      }
      return false;
    } catch (e){
      return false;
    }
  }
}
