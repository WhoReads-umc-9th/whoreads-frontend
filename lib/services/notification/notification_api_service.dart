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
      // 이미지 구조상 result 안에 contents, next_cursor, has_next가 들어있음
      return response.data['result'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// 2. 모든 알림 읽음 처리 (POST)
  Future<void> readAllNotifications(int notificationId) async {
    try {
      await ApiClient.dio.post('/notifications/me/$notificationId/read-all');
    } catch (e) {
      rethrow;
    }
  }

  /// 3. 테스트 알림 발송 (POST)
  Future<void> sendTestNotification() async {
    try {
      await ApiClient.dio.post('/notifications/me/test');
    } catch (e) {
      rethrow;
    }
  }

  /// 4. 특정 알림 읽음 처리 (PATCH)
  Future<void> readNotification(int notificationId) async {
    try {
      await ApiClient.dio.patch('/notifications/me/$notificationId/read');
    } catch (e) {
      rethrow;
    }
  }

  /// 5. 알림 삭제 (DELETE)
  Future<void> deleteNotification(int notificationId) async {
    try {
      await ApiClient.dio.delete('/notifications/me/$notificationId');
    } catch (e) {
      rethrow;
    }
  }
}
