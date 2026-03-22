import 'package:flutter/material.dart';
import 'notification_api_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationService {
  final NotificationApiService _apiService = NotificationApiService();

  // 내부 상태 관리 (Screen에서 이 변수들을 구독하게 됩니다)
  List<Map<String, dynamic>> _notifications = [];
  int? _nextCursor;
  bool _hasNext = true;
  bool _isLoading = false;

  // Getter: 외부(Screen)에서 접근 가능한 변수들
  List<dynamic> get notifications => _notifications;
  bool get hasNext => _hasNext;
  bool get isLoading => _isLoading;

  // ---------------------------------------------------------
  // 1. 알림 목록 초기 로드 및 새로고침
  // ---------------------------------------------------------
  Future<void> refresh() async {
    _notifications = [];
    _nextCursor = null;
    _hasNext = true;
    await fetchMore();
  }

  String formatTimeAgo(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';

    try {
      DateTime dateTime = DateTime.parse(createdAt);
      DateTime now = DateTime.now();
      Duration difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}주 전';
      } else if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()}달 전';
      } else {
        return '${(difference.inDays / 365).floor()}년 전';
      }
    } catch (e) {
      return ''; // 날짜 형식이 잘못된 경우 빈 문자열 반환
    }
  }

  // ---------------------------------------------------------
  // 2. 다음 페이지 로드 (무한 스크롤)
  // ---------------------------------------------------------
  Future<void> fetchMore() async {
    if (_isLoading || !_hasNext) return;

    _isLoading = true;
    try {
      final result = await _apiService.getNotifications(
        cursor: _nextCursor,
        size: 15,
      );

      // 1. 데이터 가져오기
      final List<dynamic> newItems = result['contents'] ?? [];

      // 2. [추가] 가공 로직: created_at을 timeago 포맷으로 변환
      final processedItems = newItems.map((item) {
        final Map<String, dynamic> mapItem = item as Map<String, dynamic>;

        timeago.setLocaleMessages('ko', timeago.KoMessages());

        mapItem['time'] = '';

        // 서버의 날짜 문자열을 DateTime 객체로 변환
        if (mapItem['created_at'] != null) {
          mapItem['time'] = formatTimeAgo(mapItem['created_at']);
        } else {
          mapItem['time'] = '';
        }

        return mapItem;
      }).toList();

      // 3. 기존 리스트에 합치기
      _notifications.addAll(processedItems);

      // 4. 다음 페이징 정보 저장
      _nextCursor = result['next_cursor'];
      _hasNext = result['has_next'] ?? false;
    } catch (e) {
      debugPrint("알림 페이징 에러: $e");
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  // ---------------------------------------------------------
  // 3. 알림 읽음 처리 (단건/전체)
  // ---------------------------------------------------------
  Future<void> markAsRead(int id) async {
    try {
      await _apiService.readNotification(id);
      // 로컬 상태 즉시 업데이트 (사용자 경험 개선)
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAllAsRead(int id) async {
    try {
      await _apiService.readAllNotifications(id);
      // 리스트 전체를 읽음으로 변경
      for (var n in _notifications) {
        n['is_read'] = true;
      }
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------
  // 4. 알림 삭제 및 테스트
  // ---------------------------------------------------------
  Future<void> removeNotification(int id) async {
    try {
      await _apiService.deleteNotification(id);
      _notifications.removeWhere((n) => n['id'] == id);
      // }
    } catch (e) {
      return;
    }
  }

  Future<void> triggerTest() async {
    await _apiService.sendTestNotification();
    // 테스트 발송 후 목록을 다시 불러오고 싶다면:
    await refresh();
  }
}
