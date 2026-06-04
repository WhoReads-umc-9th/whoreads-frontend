import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/reading_session_model.dart';


class TimerLocalStorage {
  TimerLocalStorage._();

  static final TimerLocalStorage instance = TimerLocalStorage._();

  static const _key = 'timer_session';

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
      'savedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_key, jsonEncode(data));
  }
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
      );
    } catch (e) {
      return null;
    }
  }
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}