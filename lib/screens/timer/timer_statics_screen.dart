import 'package:flutter/material.dart';
import 'package:whoreads/widgets/timer/date_picker.dart';
import 'package:whoreads/widgets/timer/stats_card.dart';
import 'package:whoreads/services/timer/statistics_service.dart';

class TimerStatisticsPage extends StatefulWidget {
  const TimerStatisticsPage({super.key});

  @override
  State<TimerStatisticsPage> createState() => _TimerStatisticsPageState();
}

class _TimerStatisticsPageState extends State<TimerStatisticsPage> {
  final TimerStatisticsService _service = TimerStatisticsService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdated);
    _service.fetchAllData();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdated);
    super.dispose();
  }

  void _onServiceUpdated() {
    if (mounted) {
      setState(() {});
    }
  }
  void _showDatePicker() {
    MyDatePicker.show(
      context,
      initialYear: _service.selectedYear,
      initialMonth: _service.selectedMonth,
      onConfirm: (year, month) {
        _service.updateYearMonth(year, month);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "독서 타임 통계",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TimerStatisticsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatusPreviewCard(
                        title: "오늘의 포커스(h)",
                        totalMinutes: _service.todayFocusMinutes,
                        arrowDeltaMinutes: _service.yesterdayFocusMinutes,
                        hasArrow: true,
                        icon: Icons.update,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatusPreviewCard(
                        title: "총 집중 시간",
                        totalMinutes: _service.totalFocusMinutes,
                        icon: Icons.hourglass_empty,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: StatsDetailCard(
                records: _service.records,
                selectedDate: _service.selectedYearMonth,
                onTap: _showDatePicker,
                title: '집중 기록',
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}