import 'package:flutter/cupertino.dart';
import 'package:whoreads/core/auth/token_storage.dart';
import 'package:whoreads/core/network/api_client.dart';
import '../../models/reading_session_model.dart';

class TimerApiService {
  Future<ActiveReadingSession?> getActiveSession() async {
    try {
      final response = await ApiClient.dio.get(
        '/reading-sessions/incomplete',
      );

      final data = response.data;

      if (data == null || data['result'] == null) {
        return null;
      }
      print("데이터 ${data['result']}");

      return ActiveReadingSession.fromJson(data);
    } catch (e) {
      debugPrint('getActiveSession 실패: $e');
      rethrow;
    }
  }

  Future<ActiveReadingSession> startTimer({
    required int totalMinutes,
  }) async {
    try {
      debugPrint("accessToken : ${await TokenStorage.getAccessToken()}");

      final response = await ApiClient.dio.post(
        '/reading-sessions/start',
        data: {
          'total_minutes': totalMinutes,
        },
      );

      return ActiveReadingSession.fromJson(response.data);
    } catch (e) {
      debugPrint('startTimer 실패: $e');
      rethrow;
    }
  }

  Future<ActiveReadingSession> pauseTimer(int sessionId) async {
    try {
      final response = await ApiClient.dio.post(
        '/reading-sessions/$sessionId/pause',
      );

      return ActiveReadingSession.fromJson(response.data);
    } catch (e) {
      debugPrint('pauseTimer 실패: $e');
      rethrow;
    }
  }

  Future<ActiveReadingSession> resumeTimer(int sessionId) async {
    try {
      final response = await ApiClient.dio.post(
        '/reading-sessions/$sessionId/resume',
      );

      return ActiveReadingSession.fromJson(response.data);
    } catch (e) {
      debugPrint('resumeTimer 실패: $e');
      rethrow;
    }
  }

  Future<void> completeTimer(int sessionId) async {
    try {
      await ApiClient.dio.post(
        '/reading-sessions/$sessionId/complete',
      );
    } catch (e) {
      debugPrint('completeTimer 실패: $e');
      rethrow;
    }
  }

  Future<void> cancelTimer(int sessionId) async {
    try {
      await ApiClient.dio.delete(
        '/reading-sessions/$sessionId',
      );
    } catch (e) {
      debugPrint('cancelTimer 실패: $e');
      rethrow;
    }
  }

  Future<void> heartbeat(int sessionId) async {
    try {
      await ApiClient.dio.post(
        '/reading-sessions/$sessionId/heartbeat',
      );
    } catch (e) {
      debugPrint('heartbeat 실패: $e');
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
      debugPrint('getTotalFocusTime 실패: $e');
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
      debugPrint('getTodayFocusTime 실패: $e');
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
      debugPrint('getMonthlyFocusTime 실패: $e');
      rethrow;
    }
  }
}