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
    _service.addListener(() => setState(() {}));
    _service.fetchAllData();
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
            SizedBox(height: 20),
            // 1. 상단 카드 섹션 (Padding으로 감쌈)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatusPreviewCard(
                        title: "오늘의 포커스(h)",
                        value: _service.todayFocusTime,
                        arrowValue: _service.increasedFocusTime,
                        hasArrow: true,
                        icon: Icons.update,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatusPreviewCard(
                        title: "총 집중 시간",
                        value: _service.totalFocusTime,
                        icon: Icons.hourglass_empty,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. 카드와 리스트 사이 간격 (Column의 자식으로 배치)
            const SizedBox(height: 12),

            // 3. 기록 리스트 섹션 (리스트에도 좌우 여백이 필요하면 Padding으로 감쌈)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: StatsDetailCard(
                // title 속성은 StatsDetailCard 정의에 따라 생략하거나 추가하세요.
                records: _service.records,
                selectedDate: _service.selectedYearMonth,
                onTap: _showDatePicker,
                title: '이번 달 기록',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
