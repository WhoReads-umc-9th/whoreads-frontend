import 'package:flutter/cupertino.dart';
import 'package:whoreads/core/network/api_client.dart';

import 'package:whoreads/core/auth/token_storage.dart';

class TimerApiService {
  Future<int> startTimer() async {
    try {
      debugPrint("accessToken : ${await TokenStorage.getAccessToken()}");
      final response = await ApiClient.dio.post('/reading-sessions/start');
      final sessionId = response.data['result']['session_id'];
      return sessionId;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pauseTimer(int sessionId) async {
    try {
      await ApiClient.dio.post('/reading-sessions/$sessionId/pause');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resumeTimer(int sessionId) async {
    try {
      await ApiClient.dio.post('/reading-sessions/$sessionId/resume');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> completeTimer(int sessionId) async {
    try {
      await ApiClient.dio.post('/reading-sessions/$sessionId/complete');
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getTotalFocusTime() async {
    try {
      final response = await ApiClient.dio.get(
        '/me/reading-sessions/stats/total',
      );
      return response.data['result']['total_minutes'] as int;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTodayFocusTime() async {
    try {
      final response = await ApiClient.dio.get(
        '/me/reading-sessions/stats/today',
      );
      return response.data['result'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getMonthlyFocusTime() async {
    try {
      final response = await ApiClient.dio.get(
        '/me/reading-sessions/stats/monthly',
      );
      return response.data['result'] as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
