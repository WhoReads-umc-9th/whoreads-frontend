import 'package:flutter/cupertino.dart';
import 'package:whoreads/core/network/api_client.dart';
import '../../models/reading_session_model.dart';

class TimerApiService {

  Future<void> setReadingSessionTime({required int totalMinutes}) async {
    try {
      final response = await ApiClient.dio.patch(
        '/me/reading-sessions/settings/time',
        data: {
          'time': totalMinutes,
        },
      );
      debugPrint('setReadingSessionTime 성공 : ${response.data}');
    } catch (e) {
      debugPrint('setReadingSessionTime 실패: $e');
      rethrow;
    }
  }

  Future<ActiveReadingSession?> getActiveSession() async {
    try {
      final response = await ApiClient.dio.get(
        '/reading-sessions/incomplete',
      );
      final data = response.data;
      if (data == null || data['result'] == null) {
        return null;
      }
      debugPrint('getActiveSession 성공: $data');
      return ActiveReadingSession.fromJson(data);
    } catch (e) {
      debugPrint('getActiveSession 실패: $e');
      rethrow;
    }
  }

  Future<int> startTimer({required int totalMinutes}) async {
    try {
      final response = await ApiClient.dio.post(
        '/reading-sessions/start',
      );
      return response.data['result']['session_id'];
    } catch (e) {
      debugPrint('startTimer 실패: $e');
      rethrow;
    }
  }

  Future<void> pauseTimer(int sessionId) async {
    try {
      final response = await ApiClient.dio.post(
        '/reading-sessions/$sessionId/pause',
      );
    } catch (e) {
      debugPrint('pauseTimer 실패: $e');
      rethrow;
    }
  }

  Future<void> resumeTimer(int sessionId) async {
    try {
      await ApiClient.dio.post(
        '/reading-sessions/$sessionId/resume',
      );
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