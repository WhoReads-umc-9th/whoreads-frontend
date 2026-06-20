import 'package:flutter/material.dart';
import 'package:whoreads/core/network/api_client.dart';

class NotificationApiService {
  /// 1. 알림 내역 조회 (GET) - 커서 페이징 적용
  /// cursor: 마지막으로 받은 데이터의 ID (첫 호출 시 null)
  /// size: 한 번에 가져올 개수
  Future<Map<String, dynamic>> getNotifications({
    int? cursor,
    int size = 10,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        '/notifications/me',
        queryParameters: {if (cursor != null) 'cursor': cursor, 'size': size},
      );
      return response.data['result'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// 2. 모든 알림 읽음 처리 (POST)
  Future<void> readAllNotifications() async {
    try {
      await ApiClient.dio.post('/notifications/me/read-all');
    } catch (e) {
      rethrow;
    }
  }

  /// 4. 특정 알림 읽음 처리 (PATCH)
  Future<void> readNotification(String notificationId) async {
    try {
      await ApiClient.dio.patch('/notifications/me/$notificationId/read');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await ApiClient.dio.delete('/notifications/me/$notificationId');
    } catch (e) {
      rethrow;
    }
  }
  Future<void> addNotificationSetting({
    List<String>? days,
    String? time,
    required String notificationType
  })
  async {
    try {
      await ApiClient.dio.post(
        '/notifications/me/settings',
        data: {
          'time': time,
          'type': notificationType,
          'days': days,
          'is_enabled' : true,
        },
      );

    } catch (e) {
      debugPrint('routine 추가 실패: $e');
      rethrow;
    }
  }
  Future<Map<String,dynamic>> getNotificationSetting({
    String? notificationType
  })
  async {
    try {
      final response = await ApiClient.dio.get(
        '/notifications/me/settings',
        queryParameters: {
          if (notificationType != null) 'type': notificationType,
        },
      );
      return response.data['result'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('routine 추가 실패: $e');
      rethrow;
    }
  }
  Future<void> deleteNotificationSetting({
    required int notificationSettingId
  })
  async {
    try {
      await ApiClient.dio.delete(
        '/notifications/me/settings/$notificationSettingId',
      );
    } catch (e) {
      debugPrint('routine 삭제 실패: $e');
      rethrow;
    }
  }
  Future<void> updateNotificationSetting({
    List<String>? days,
    String? time,
    required String notificationType,
    required bool isEnabled,
    required int notificationSettingId,
  })
  async {
    try {
      await ApiClient.dio.patch(
        '/notifications/me/settings/$notificationSettingId',
        data: {
          'time': time,
          'type': notificationType,
          'days': days,
          'is_enabled' : isEnabled,
        },
      );

    } catch (e) {
      debugPrint('routine 수정 실패: $e');
      rethrow;
    }
  }
}
