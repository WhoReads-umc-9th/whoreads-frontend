class ActiveReadingSession {
  final int sessionId;
  final String status;

  final int totalReadMinutes;
  final int remainingMinutes;
  final int idleMinutes;

  final bool focusBlockEnabled;
  final bool whiteNoiseEnabled;

  final DateTime serverTime;

  ActiveReadingSession({
    required this.sessionId,
    required this.status,
    required this.totalReadMinutes,
    required this.remainingMinutes,
    required this.idleMinutes,
    required this.focusBlockEnabled,
    required this.whiteNoiseEnabled,
    required this.serverTime,
  });

  bool get isRunning => status == 'RUNNING';
  bool get isPaused => status == 'PAUSED';

  bool get canResume => idleMinutes <= 120;

  int get remainingSeconds => remainingMinutes * 60;

  factory ActiveReadingSession.fromJson(Map<String, dynamic> json) {
    final result = json['result'];


    return ActiveReadingSession(
      sessionId: result['sessionId'],
      status: result['status'],
      totalReadMinutes: result['totalReadMinutes'],
      remainingMinutes: result['remainingMinutes'],
      idleMinutes: result['idleMinutes'],
      focusBlockEnabled: result['focusBlockEnabled'],
      whiteNoiseEnabled: result['whiteNoiseEnabled'],
      serverTime: DateTime.parse(json['server_time']),
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
      'serverTime': serverTime.toIso8601String(),
    };
  }
}