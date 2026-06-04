import 'package:flutter/material.dart';

class StatsDetailCard extends StatelessWidget {
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
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    SizedBox(
                      width: 48,
                      child: Text(
                        item['date'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1B1F),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['timeRange'] ?? '시간 정보 없음',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    Text(
                      item['duration'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1B1F),
                        fontSize: 14,
                      ),
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
  final int totalMinutes;
  final int? arrowDeltaMinutes;
  final bool hasArrow;
  final IconData? icon;

  const StatusPreviewCard({
    super.key,
    required this.title,
    required this.totalMinutes,
    this.arrowDeltaMinutes,
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
          const SizedBox(height: 4),

          if (hasArrow && arrowDeltaMinutes != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      "어제 ${_formatSubText(arrowDeltaMinutes!)}",
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      arrowDeltaMinutes! >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: arrowDeltaMinutes! >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            )
          else
            const SizedBox(),

          _buildCustomFormattedTime(totalMinutes),
        ],
      ),
    );
  }

  Widget _buildCustomFormattedTime(int totalMin) {
    final int hours = totalMin ~/ 60;
    final int minutes = totalMin % 60;

    const TextStyle numberStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1C1B1F),
      fontFamily: 'Roboto',
    );

    const TextStyle unitStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(hours.toString().padLeft(2, '0'), style: numberStyle),
        const Padding(
          padding: EdgeInsets.only(bottom: 2, left: 2, right: 6),
          child: Text('h', style: unitStyle),
        ),
        Text(minutes.toString().padLeft(2, '0'), style: numberStyle),
        const Padding(
          padding: EdgeInsets.only(bottom: 2, left: 2),
          child: Text('m', style: unitStyle),
        ),
      ],
    );
  }

  String _formatSubText(int min) {
    final int absMin = min.abs();
    final int h = absMin ~/ 60;
    final int m = absMin % 60;
    return "${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m";
  }
}