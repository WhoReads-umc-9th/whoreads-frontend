import 'package:flutter/material.dart';

class StatsDetailCard extends StatelessWidget {
  // 생성자 파라미터들 (필요한 것만 남김)
  final List<Map<String, String>> records;
  final String selectedDate;
  final VoidCallback onTap;
  final String title;

  const StatsDetailCard({
    super.key,
    required this.title,
    required this.records,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    selectedDate,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (records.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("기록이 없습니다.", style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...records.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Text(
                      item['date'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item['timeRange'] ?? '시간 정보 없음',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    Text(
                      item['duration'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}

class StatusPreviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String? arrowValue;
  final bool hasArrow;
  final IconData? icon;

  const StatusPreviewCard({
    super.key,
    required this.title,
    required this.value,
    this.arrowValue,
    this.hasArrow = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 상단: 타이틀 + 아이콘
          Row(
            children: [
              Icon(
                icon ?? Icons.access_time,
                size: 24,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          if (hasArrow && arrowValue != null)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start, // 왼쪽 정렬
                  children: [
                    Text(
                      "어제 $arrowValue",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Icon(
                      Icons.arrow_upward,
                      size: 13,
                      color: Colors.green,
                    ),
                  ],
                ),
                // Row 바깥(아래)에 간격을 줍니다.
                const SizedBox(height: 4),
              ],
            )
          else
            const SizedBox(),

          // 하단: 메인 값
          _buildValueText(value),
        ],
      ),
    );
  }

  Widget _buildValueText(String value) {
    final parts = value.split(' ');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: parts.map((part) {
        final unitMatch = RegExp(r'^(\d+)(h|m)$').firstMatch(part);
        if (unitMatch != null) {
          final number = unitMatch.group(1)!;
          final unit = unitMatch.group(2)!;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3, right: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        }
        return Text(
          part,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        );
      }).toList(),
    );
  }
}
