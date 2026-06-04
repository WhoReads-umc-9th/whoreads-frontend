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
}
