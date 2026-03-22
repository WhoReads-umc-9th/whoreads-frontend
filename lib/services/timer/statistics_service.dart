import 'package:flutter/material.dart';

import 'timer_api_service.dart';

class TimerStatisticsService extends ChangeNotifier {
  final TimerApiService _apiService = TimerApiService();

  // 1. 상태 데이터 (상단 카드용)
  String todayFocusTime = "0h 0m";
  String totalFocusTime = "0h 0m";
  String selectedYear = DateTime.now().year.toString();
  String selectedMonth = DateTime.now().month.toString();
  String selectedYearMonth = "${DateTime.now().year}년 ${DateTime.now().month}월";
  String increasedFocusTime = "0m";

  // 2. 리스트 데이터 (집중 기록용)
  List<Map<String, String>> records = [];

  Future<void> fetchAllData() async {
    try {
      await Future.wait([
        // 오늘 데이터 가져오기
        _apiService.getTodayFocusTime().then((data) {
          todayFocusTime = _formatTime(data['today_minutes'] ?? 0);
          increasedFocusTime = _formatTime(
            data['difference_from_yesterday'] ?? 0,
          );
        }),

        // 전체 집중 시간 가져오기
        _apiService.getTotalFocusTime().then((time) {
          totalFocusTime = _formatTime(time);
        }),

        // 월간 기록 가져오기
        _apiService.getMonthlyFocusTime().then((fetchRecords) {
          records = fetchRecords.map((item) {
            final String start = item['start_time'] ?? "00:00";
            final String end = item['end_time'] ?? "00:00";
            final int duration = item['total_minutes'] ?? 0;

            return {
              "date": "${item['day']}일", // '1' -> '1일'
              "timeRange": formatTimeRange(start, end), // '14:00' -> '오후 2:00'
              "duration": "${duration}m", // '45' -> '00:45'
            };
          }).toList();
        }),
      ]);
      notifyListeners();
    } catch (e) {
      return;
    }
  }

  String _formatTime(int minutes) {
    String hour = (minutes ~/ 60).toString().padLeft(2, '0');
    String remainingMinutes = (minutes % 60).toString().padLeft(2, '0');
    return '${hour}h${remainingMinutes.toString().padLeft(2, '0')}m';
  }

  String formatTimeRange(String start, String end) {
    String convert(String time) {
      List<String> parts = time.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      String period = hour < 12 ? "오전" : "오후";
      int displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;

      // 분이 한 자릿수일 경우를 대비해 padLeft 사용 (예: 2:05)
      String displayMinute = minute.toString().padLeft(2, '0');

      return "$period $displayHour:$displayMinute";
    }

    return "${convert(start)} - ${convert(end)}";
  }

  // 3. 날짜 변경 로직
  void updateYearMonth(String year, String month) {
    selectedMonth = month;
    selectedYear = year;
    selectedYearMonth = "$year년 $month월";
    notifyListeners();
  }
}
