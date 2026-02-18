import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/auth/token_storage.dart';
import '../../../models/library_summary_model.dart';

class ReadingSummaryCard extends StatefulWidget {
  final String username;
  final String accessToken;

  const ReadingSummaryCard({
    super.key,
    required this.username,
    required this.accessToken,
  });

  @override
  State<ReadingSummaryCard> createState() => _ReadingSummaryCardState();
}

class _ReadingSummaryCardState extends State<ReadingSummaryCard> {
  LibrarySummaryModel? summary;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final token = await TokenStorage.getAccessToken();

      final response = await http.get(
        Uri.parse('http://43.201.122.162/api/me/library/summary'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          decoded['is_success'] == true) {

        final result = decoded['result'];

        setState(() {
          summary = LibrarySummaryModel(
            completedCount: result['completed_count'],
            readingCount: result['reading_count'],
            totalReadMinutes: result['total_read_minutes'],
          );
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('요약 불러오기 실패: $e');
      setState(() => isLoading = false);
    }
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    return '${hours}h ${remainMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFF6A00)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.username}님의 기록',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                title: '읽은 책',
                value: '${summary?.completedCount ?? 0}권',
              ),
              _SummaryItem(
                title: '읽는 중',
                value: '${summary?.readingCount ?? 0}권',
              ),
              _SummaryItem(
                title: '누적 독서 시간',
                value: _formatMinutes(summary?.totalReadMinutes ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
