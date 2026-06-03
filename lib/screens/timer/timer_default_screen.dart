import 'package:flutter/material.dart';
import 'package:whoreads/services/timer/timer_service.dart';
import 'package:whoreads/widgets/timer/time_picker.dart';
import 'package:whoreads/widgets/timer/timer_view.dart';
import 'timer_statics_screen.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final TimerService _service = TimerService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _service.restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildTimerDisplay() {
    Widget child;
    if (!_service.isRunning && !_service.isStopping) {
      child = Center(
        child: TimePickerWidget(onTimeSelected: _service.onTimeSelected),
      );
    } else {
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
            onTap: () async {
              await _service.resetTimer();
            },
          ),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    String label;
    VoidCallback onTap;
    Color color = const Color(0xFFFF5722);


    if (_service.isStopping) {
      label = '재개';
      onTap = () async {
        await _service.resumeTimer();
      };
    } else if (!_service.isStopping && _service.isRunning) {
      label = '일시정지';
      onTap = () async {
        await _service.pauseTimer();
      };
      color = const Color(0xFFFFAB91);
    } else {
      label = '시작';
      onTap = () async {
        await _service.startTimer();
      };
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
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
        IconButton(
          icon: const Icon(Icons.bar_chart, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TimerStatisticsPage()),
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}