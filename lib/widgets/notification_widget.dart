import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

enum NotificationType {
  follow("FOLLOW"),
  routine("ROUTINE"),
  none("NONE");

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String? type) {
    return NotificationType.values.firstWhere(
      (e) => e.value == type,
      orElse: () => NotificationType.none,
    );
  }
}

Map<NotificationType, String> notificationTypeToString = {
  NotificationType.follow: '서재 업데이트',
  NotificationType.routine: '독서 루틴 알림',
  NotificationType.none: '알림',
};

class NotificationWidget extends StatelessWidget {
  final NotificationType type;
  final String body;
  final String time; // 가공된 "40분 전" 데이터
  final bool isRead;
  final Map<String, dynamic>? link; // 서버에서 주는 link 객체 (상세 이동용)
  final VoidCallback? onTap; // 클릭 이벤트 처리를 위해 추가

  const NotificationWidget({
    super.key,
    required this.type,
    required this.body,
    required this.time,
    this.isRead = true,
    this.link,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // 1. 읽지 않은 알림은 연한 주황색 배경 적용
        color: isRead
            ? Colors.white
            : const Color(0xFFFB9566).withValues(alpha: 0.1),
        padding: const EdgeInsets.all(16),
        child: Row(
          // 2. 아이콘을 텍스트의 첫 줄 높이에 맞추기 위해 상단 정렬
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/images/basic/libarary.svg',
              width: 24,
              height: 24,
              // ignore: deprecated_member_use
              color: const Color(0xFFFB9566),
            ),
            const SizedBox(width: 8),

            // 4. 나머지 텍스트 영역을 꽉 채우도록 Expanded 처리
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 카테고리명과 시간 (양 끝 정렬)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notificationTypeToString[type] ?? '알림',
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF505050),
                      fontWeight: FontWeight.w600,
                      height: 1.3, // 줄 간격을 줘서 가독성 확보
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
