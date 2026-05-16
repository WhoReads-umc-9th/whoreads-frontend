import 'package:flutter/cupertino.dart';

class ActiveReadingSession {
  final int sessionId;
  final String status;

  final int totalReadMinutes;
  final int remainingMinutes;
  final int idleMinutes;

  final bool focusBlockEnabled;
  final bool whiteNoiseEnabled;


  ActiveReadingSession({
    required this.sessionId,
    required this.status,
    required this.totalReadMinutes,
    required this.remainingMinutes,
    required this.idleMinutes,
    required this.focusBlockEnabled,
    required this.whiteNoiseEnabled,
  });

  bool get isRunning => status == 'RUNNING';
  bool get isPaused => status == 'PAUSED';

  bool get canResume => idleMinutes <= 120;

  int get remainingSeconds => remainingMinutes * 60;

  factory ActiveReadingSession.fromJson(Map<String, dynamic> json) {
    final result = json['result'];

    debugPrint('ActiveReadingSession.fromJson 성공: $result');


    return ActiveReadingSession(
      sessionId: result['session_id'],
      status: result['status'],
      totalReadMinutes: result['total_read_minutes'],
      remainingMinutes: result['remaining_minutes'],
      idleMinutes: result['idle_minutes'],
      focusBlockEnabled: result['focus_block_enabled'],
      whiteNoiseEnabled: result['white_noise_enabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'status': status,
      'totalReadMinutes': totalReadMinutes,
      'remainingMinutes': remainingMinutes,
      'idleMinutes': idleMinutes,
      'focusBlockEnabled': focusBlockEnabled,
      'whiteNoiseEnabled': whiteNoiseEnabled,
    };
  }
}