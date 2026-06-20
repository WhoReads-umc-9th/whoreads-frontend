import 'package:flutter/cupertino.dart';
import 'package:whoreads/services/notification/notification_api_service.dart';

enum Day {
  monday, tuesday, wednesday, thursday, friday, saturday, sunday;
  String get toServerParam => name.toUpperCase();
}

enum TimePeriod {
  am('AM'),
  pm('PM');

  const TimePeriod(this.value);
  final String value;
}

enum NotificationSettingType {
  follow,
  routine;

  String get toServerParam => name.toUpperCase();
}
class NotificationSettingService {
  final NotificationApiService _notificationApiService = NotificationApiService();
  Future<void> addRoutine({
    required TimePeriod timePeriod,
    List<Day>? days,
    int? hour,
    int? minutes,
  }) async {
    try {
      final int actualHour = _convertTo24Hour(timePeriod, hour ?? 0);
      final String formattedTime = '${actualHour.toString().padLeft(2, '0')}:${(minutes ?? 0).toString().padLeft(2, '0')}';
      final List<String>? daysParam = days?.map((day) => day.toServerParam).toList();

      _notificationApiService.addNotificationSetting(
          notificationType: NotificationSettingType.routine.toServerParam,
          days: daysParam,
          time: formattedTime
      );
    } catch (e) {
      debugPrint('routine 추가 실패: $e');
      rethrow;
    }
  }
  Future<Map<String,dynamic>?> getAllSettings() async {
    try {
      final Map<String,dynamic> response =
      await _notificationApiService
          .getNotificationSetting();
      return response;
    } catch (e) {
      debugPrint("루틴 설정 가져오기 실패 : $e");
      return null;
    }
  }



  Future<void> updateSetting({
    required int settingId,
    required NotificationSettingType notificationType,
    required bool isEnabled,
    String? rawTimeStr,
    List<String>? rawDayStr,
    TimePeriod? timePeriod,
    int? hour,
    int? minutes,
    List<Day>? days,
  }) async {
    try {
      String? formattedTime;
      List<String>? daysParam;

      if (notificationType == NotificationSettingType.routine) {
        if (rawTimeStr == null && (timePeriod == null || hour == null || minutes == null || days == null)) {
          throw Exception("ROUTINE 타입 수정 시에는 시간, 분, 요일 데이터가 필수입니다.");
        }
        if (rawTimeStr != null && rawDayStr != null) {
          formattedTime = rawTimeStr.length >= 5 ? rawTimeStr.substring(0, 5) : rawTimeStr;
          daysParam = rawDayStr;
        }
        else {
          final int actualHour = _convertTo24Hour(timePeriod!, hour ?? 0);
          formattedTime = '${actualHour.toString().padLeft(2, '0')}:${(minutes ?? 0).toString().padLeft(2, '0')}';
          daysParam = days?.map((day) => day.toServerParam).toList();
        }
      }

      await _notificationApiService.updateNotificationSetting(
        notificationType: notificationType.toServerParam,
        isEnabled: isEnabled,
        time: formattedTime,
        days: daysParam,
        notificationSettingId: settingId,
      );
      debugPrint('${notificationType.name} 수정 성공 (ID: $settingId, 활성화: $isEnabled)');
    } catch (e) {
      debugPrint('${notificationType.name} 수정 실패: $e');
      rethrow;
    }
  }

  Future<void> addFollowSetting() async {
    try {
      _notificationApiService.addNotificationSetting(
          notificationType: NotificationSettingType.follow.toServerParam,
      );
    } catch (e) {
      debugPrint('routine 추가 실패: $e');
      rethrow;
    }
  }

  int _convertTo24Hour(TimePeriod period, int hour) {
    if (period == TimePeriod.pm && hour != 12) {
      return hour + 12;
    } else if (period == TimePeriod.am && hour == 12) {
      return 0;
    }
    return hour;
  }

  Future<void> deleteSetting({required int settingId}) async {
    try {
      _notificationApiService.deleteNotificationSetting(
          notificationSettingId: settingId);
    } catch (e) {
      debugPrint("삭제 실패 : $e");
    }
  }
}