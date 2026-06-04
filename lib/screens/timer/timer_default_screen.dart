import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';
import 'package:whoreads/services/timer/timer_service.dart';
import 'package:whoreads/widgets/timer/time_picker.dart';
import 'package:whoreads/widgets/timer/timer_view.dart';
import 'package:whoreads/widgets/timer/timer_popup.dart';
import 'timer_statics_screen.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with WidgetsBindingObserver {
  final TimerService _service = TimerService();
  bool _isPopupShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_service.handleForegroundData);

    Future.microtask(() async {
      _manageRecoveryTrigger();
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_service.handleForegroundData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _manageRecoveryTrigger() async {
    if (_isPopupShowing) return;

    final type = await _service.checkRecoveryState();

    if (type == TimerRecoveryType.none) return;

    setState(() { _isPopupShowing = true; });

    String title = "";
    String? description;
    List<HighlightText> highlights = [];
    String leftText = "종료하기";
    String rightText = "이어하기";
    VoidCallback? onLeft;
    VoidCallback? onRight;
    bool isSingle = false;

    final String recordStr = "${_service.elapsedSeconds ~/ 60}분";
    final String pauseStr = "${_service.pausedSeconds}분 경과";
    final String remainStr = "${_service.currentSeconds ~/ 60}분";

    switch (type) {
      case TimerRecoveryType.timerCompleted:
        title = "축하합니다!\n ${_service.totalSeconds ~/ 60}분 동안 독서를 완료하였습니다.";
        description = "읽은 책의 진행률을 기록해주세요!";
        rightText = "확인";
        isSingle = true;
        onRight = () async {
          await _service.handleExitAction();
          _closePopup();
        };
      case TimerRecoveryType.pausedWithLeft:
        title = "문제가 발생하여 타이머가 중단되었습니다.\n이전 독서를 이어할까요?";
        description = "이어하면 중단된 시간이 반영돼요\n종료하면 기록된 시간만 남아요!";
        highlights = [
          HighlightText(label: "기록", value: recordStr),
          HighlightText(label: "중단", value: pauseStr),
          HighlightText(label: "남은시간", value: remainStr),
        ];
        onLeft = () async {
          await _service.handleExitAction();
          _closePopup();
        };
        onRight = () async {
          await _service.handleResumeAction();
          _closePopup();
        };
        break;

      case TimerRecoveryType.pausedNoLeft:
        title = "문제가 발생하여 타이머가 중단되었습니다";
        description = "반영하면 중단된 시간도 반영돼요\n종료하면 기록된 시간만 남아요!";
        rightText = "반영하기";
        highlights = [
          HighlightText(label: "기록", value: recordStr),
          HighlightText(label: "중단", value: pauseStr),
        ];
        onLeft = () async {
          await _service.handleExitAction();
          _closePopup();
        };
        onRight = () async {
          await _service.handleReflectAction();
          _closePopup();
        };
        break;

      case TimerRecoveryType.forceTerminated:
        title = "독서 타이머가 오래 중단되어\n자동 종료되었습니다";
        description = "2시간 이상 중단되면 이전 독서를 이어할 수 없습니다.\n새로운 독서를 시작해볼까요?";
        rightText = "확인";
        isSingle = true;
        highlights = [
          HighlightText(label: "기록", value: recordStr),
        ];
        onRight = () async {
          await _service.handleExitAction();
          _closePopup();
        };
        break;
      default:
        return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TimerPopup(
        title: title,
        description: description,
        highlights: highlights,
        leftButtonText: leftText,
        rightButtonText: rightText,
        singleButton: isSingle,
        onLeftPressed: onLeft,
        onRightPressed: onRight,
      ),
    );
  }
  void _closePopup() {
    if (mounted) {
      Navigator.of(context).pop();
      setState(() { _isPopupShowing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: WithForegroundTask(
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
              fontWeight: textColor == Colors.white ? FontWeight.bold : FontWeight.w500,
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
        onPressed: () => {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyLibraryPage()),
          )
        },
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