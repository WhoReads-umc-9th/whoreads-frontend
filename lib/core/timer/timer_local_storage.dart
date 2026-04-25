import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/reading_session_model.dart';


class TimerLocalStorage {
  TimerLocalStorage._();

  static final TimerLocalStorage instance = TimerLocalStorage._();

  static const _key = 'timer_session';

  // =========================
  // 저장
  // =========================
  Future<void> save(ActiveReadingSession session) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'sessionId': session.sessionId,
      'status': session.status,
      'totalReadMinutes': session.totalReadMinutes,
      'remainingMinutes': session.remainingMinutes,
      'idleMinutes': session.idleMinutes,
      'focusBlockEnabled': session.focusBlockEnabled,
      'whiteNoiseEnabled': session.whiteNoiseEnabled,
      'serverTime': session.serverTime.toIso8601String(),
      'savedAt': DateTime.now().toIso8601String(), // ⭐ 중요
    };

    await prefs.setString(_key, jsonEncode(data));
  }

  // =========================
  // 불러오기
  // =========================
  Future<ActiveReadingSession?> load() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = prefs.getString(_key);

    if (jsonString == null) return null;

    try {
      final data = jsonDecode(jsonString);

      return ActiveReadingSession(
        sessionId: data['sessionId'],
        status: data['status'],
        totalReadMinutes: data['totalReadMinutes'],
        remainingMinutes: data['remainingMinutes'],
        idleMinutes: data['idleMinutes'],
        focusBlockEnabled: data['focusBlockEnabled'],
        whiteNoiseEnabled: data['whiteNoiseEnabled'],
        serverTime: DateTime.parse(data['serverTime']),
      );
    } catch (e) {
      return null;
    }
  }

  // =========================
  // 삭제
  // =========================
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // =========================
  // 존재 여부
  // =========================
  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}