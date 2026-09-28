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
    }
  }

  Future<bool> getLoggedIn() async {
    try {
      final token = await TokenStorage.getAccessToken();

      if (token != null) {
        final bool isTokenValid = await ApiClient.attemptTokenRefresh();
        return isTokenValid;
      }
      return false;
    } catch (e) {
      return (await TokenStorage.getAccessToken())?.isNotEmpty == true;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final response = await ApiClient.dio.patch("/auth/delete");
      if (response.statusCode == 200 || response.statusCode == 204) {
        await TokenStorage.clear();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("회원탈퇴 실패: $e");
      return false;
    }
  }
}
