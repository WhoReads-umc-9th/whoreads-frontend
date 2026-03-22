import 'package:flutter/material.dart';
import 'package:whoreads/screens/timer/timer_statics_screen.dart';
import 'package:whoreads/services/timer/timer_service.dart';
import 'package:whoreads/widgets/timer/time_picker.dart';
import 'package:whoreads/widgets/timer/timer_view.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final TimerService _service = TimerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              _buildTimerDisplay(),
              const SizedBox(height: 40),
              _buildControlButtons(),
            ],
          );
        },
      ),
    );
  }

  // 1. 타이머 표시부 (피커 or 시계)
  Widget _buildTimerDisplay() {
    Widget child;

    if (!_service.isRunning) {
      child = Center(
        child: TimePickerWidget(onTimeSelected: _service.onTimeSelected),
      );
    } else {
      // 나누기 0 오류 방지
      double progress = _service.totalSeconds > 0
          ? _service.currentSeconds / _service.totalSeconds
          : 0.0;

      child = Center(
        child: TimerViewWidget(
          timeText: _service.formatTime(_service.currentSeconds),
          percentage: progress,
        ),
      );
    }

    return SizedBox(height: 280, child: child);
  }

  // 2. 하단 컨트롤 버튼 레이아웃
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _roundButton(
            label: '취소',
            color: const Color(0xFFEFF1F3),
            textColor: Colors.black,
            onTap: _service.resetTimer,
          ),
          _buildActionButton(), // 시작/일시정지/재개 상황별 버튼
        ],
      ),
    );
  }

  // 3. 상황에 따른 우측 액션 버튼 생성
  Widget _buildActionButton() {
    String label;
    VoidCallback onTap;
    Color color = const Color(0xFFFF5722); // 기본 오렌지색

    if (!_service.isRunning) {
      label = '시작';
      onTap = _service.startTimer;
    } else if (!_service.isStopping) {
      label = '일시정지';
      onTap = _service.pauseTimer;
      color = const Color(0xFFFFAB91); // 연한 오렌지
    } else {
      label = '재개';
      onTap = _service.resumeTimer;
    }

    return _roundButton(
      label: label,
      color: color,
      textColor: Colors.white,
      onTap: onTap,
    );
  }

  Widget _roundButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // AppBar 분리 (가독성)
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.bar_chart, color: Colors.black),
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
    );
  }
}
