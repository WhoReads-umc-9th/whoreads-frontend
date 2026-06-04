import 'package:flutter/material.dart';
import 'timer_api_service.dart';

class TimerStatisticsService with ChangeNotifier {
  final TimerApiService _apiService = TimerApiService();

  int todayFocusMinutes = 0;
  int yesterdayFocusMinutes = 0;
  int totalFocusMinutes = 0;

  String selectedYear = DateTime.now().year.toString();
  String selectedMonth = DateTime.now().month.toString();
  String selectedYearMonth = "${DateTime.now().year}년 ${DateTime.now().month}월";

  // 2. 리스트 데이터 (집중 기록용)
  List<Map<String, String>> records = [];

  Future<void> fetchAllData() async {
    try {
      await Future.wait([
        _apiService.getTodayFocusTime().then((data) {
          todayFocusMinutes = data['today_minutes'] ?? 0;
          yesterdayFocusMinutes = data['difference_from_yesterday'] ?? 0;
        }),

        _apiService.getTotalFocusTime().then((time) {
          totalFocusMinutes = time;
        }),

        _apiService.getMonthlyFocusTime(selectedYear, selectedMonth).then((fetchRecords) {
          String? lastProcessedDay;

          records = fetchRecords.map((item) {
            final String currentDay = (item['day'] ?? "").toString();
            final String start = item['start_time'] ?? "00:00";
            final String end = item['end_time'] ?? "00:00";
            final int duration = item['total_minutes'] ?? 0;

            String displayDay = "";
            if (currentDay != lastProcessedDay) {
              displayDay = "${currentDay}일";
              lastProcessedDay = currentDay;
            }

            return {
              "date": displayDay,
              "timeRange": formatTimeRange(start, end),
              "duration": "${duration}m",
            };
          }).toList();
        }),
      ]);
      notifyListeners();
    } catch (e) {
      debugPrint('통계 데이터 패치 실패: $e');
      return;
    }
  }

  String formatTimeRange(String start, String end) {
    String convert(String time) {
      List<String> parts = time.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      String period = hour < 12 ? "오전" : "오후";
      int displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;

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
    fetchAllData();
  }
}