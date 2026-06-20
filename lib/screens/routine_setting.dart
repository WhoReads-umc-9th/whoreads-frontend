import 'package:flutter/material.dart';
import 'package:whoreads/services/notification_setting.dart';
import 'package:whoreads/widgets/timer/timer_popup.dart';

class RoutineSettingPage extends StatefulWidget {
  final Map<String, dynamic>? routine;

  const RoutineSettingPage({super.key, this.routine});

  @override
  State<RoutineSettingPage> createState() => _RoutineSettingPageState();
}

class _RoutineSettingPageState extends State<RoutineSettingPage> {
  final NotificationSettingService _settingService = NotificationSettingService();

  final List<String> _ampmList = ['오전', '오후'];
  final List<String> _hourList = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  final List<String> _minuteList = List.generate(60, (i) => i.toString().padLeft(2, '0'));

  int _selectedAmpmIndex = 0;
  int _selectedHourIndex = 8;
  int _selectedMinuteIndex = 0;

  late FixedExtentScrollController _ampmController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  final List<String> _daysKor = ['일', '월', '화', '수', '목', '금', '토'];
  final List<String> _daysEng = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
  final List<bool> _selectedDays = List.generate(7, (_) => false);

  int _initAmpmIndex = 0;
  int _initHourIndex = 8;
  int _initMinuteIndex = 0;
  List<bool> _initDays = List.generate(7, (_) => false);

  bool get _isEditMode => widget.routine != null;
  bool get _hasSelectedAnyDay => _selectedDays.contains(true);

  bool get _isDataChanged {
    if (!_isEditMode) return true;

    final bool isTimeChanged = _selectedAmpmIndex != _initAmpmIndex ||
        _selectedHourIndex != _initHourIndex ||
        _selectedMinuteIndex != _initMinuteIndex;

    bool isDaysChanged = false;
    for (int i = 0; i < 7; i++) {
      if (_selectedDays[i] != _initDays[i]) {
        isDaysChanged = true;
        break;
      }
    }

    return isTimeChanged || isDaysChanged;
  }

  bool get _isSaveButtonEnabled {
    if (!_hasSelectedAnyDay) return false;
    return _isDataChanged;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();

    _ampmController = FixedExtentScrollController(initialItem: _selectedAmpmIndex);
    _hourController = FixedExtentScrollController(initialItem: _selectedHourIndex);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinuteIndex);
  }

  @override
  void dispose() {
    _ampmController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _initializeData() {
    if (!_isEditMode) return;

    final String? timeStr = widget.routine!['time'];
    if (timeStr != null && timeStr.isNotEmpty) {
      final parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      if (hour >= 12) {
        _selectedAmpmIndex = 1;
        if (hour > 12) hour -= 12;
      } else {
        _selectedAmpmIndex = 0;
        if (hour == 0) hour = 12;
      }
      _selectedHourIndex = hour - 1;
      _selectedMinuteIndex = minute;

      _initAmpmIndex = _selectedAmpmIndex;
      _initHourIndex = _selectedHourIndex;
      _initMinuteIndex = _selectedMinuteIndex;
    }

    final List<dynamic> currentDays = widget.routine!['days'] ?? [];
    for (var day in currentDays) {
      int idx = _daysEng.indexOf(day.toString());
      if (idx != -1) {
        _selectedDays[idx] = true;
        _initDays[idx] = true;
      }
    }
  }

  void _showExitWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TimerPopup(
        title: '독서 루틴 알림이 생성되지 않았습니다.\n정말 나가시겠습니까?',
        leftButtonText: '취소',
        rightButtonText: '확인',
        singleButton: false,
        onLeftPressed: () => Navigator.pop(context),
        onRightPressed: () {
          Navigator.pop(context); // 팝업 닫기
          Navigator.pop(context); // 화면 이탈
        },
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TimerPopup(
        title: '독서 루틴 알림을 삭제하시겠습니까?',
        leftButtonText: '취소',
        rightButtonText: '확인',
        singleButton: false,
        onLeftPressed: () => Navigator.pop(context),
        onRightPressed: () async {
          try {
            Navigator.pop(context);

            await _settingService.deleteSetting(
              settingId: widget.routine!['id'],
            );

            if (mounted) Navigator.pop(context);
          } catch (e) {
            debugPrint("루틴 알림 삭제 오류: $e");
          }
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_isSaveButtonEnabled) return;

    final List<Day> selectedDaysEnum = [];
    for (int i = 0; i < 7; i++) {
      if (_selectedDays[i]) {
        selectedDaysEnum.add(Day.values.firstWhere((e) => e.toServerParam == _daysEng[i]));
      }
    }

    final int targetHour = _selectedHourIndex + 1;
    final TimePeriod targetPeriod = _selectedAmpmIndex == 0 ? TimePeriod.am : TimePeriod.pm;

    try {
      if (_isEditMode) {
        await _settingService.updateSetting(
          settingId: widget.routine!['id'],
          notificationType: NotificationSettingType.routine,
          isEnabled: widget.routine!['is_enabled'] ?? true,
          timePeriod: targetPeriod,
          hour: targetHour,
          minutes: _selectedMinuteIndex,
          days: selectedDaysEnum,
        );
      } else {
        await _settingService.addRoutine(
          timePeriod: targetPeriod,
          hour: targetHour,
          minutes: _selectedMinuteIndex,
          days: selectedDaysEnum,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("저장 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () {
            if (!_hasSelectedAnyDay) {
              _showExitWarningDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isEditMode ? '독서 루틴 알림' : '알림 추가',
          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black),
              onPressed: _showDeleteDialog,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFF5722), width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Expanded(child: _buildPickerWheel(controller: _ampmController, items: _ampmList, selectedIndex: _selectedAmpmIndex, onChanged: (index) => setState(() => _selectedAmpmIndex = index))),
                        Expanded(child: _buildPickerWheel(controller: _hourController, items: _hourList, selectedIndex: _selectedHourIndex, onChanged: (index) => setState(() => _selectedHourIndex = index))),
                        const Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                        Expanded(child: _buildPickerWheel(controller: _minuteController, items: _minuteList, selectedIndex: _selectedMinuteIndex, onChanged: (index) => setState(() => _selectedMinuteIndex = index))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  final dayStr = _daysKor[index];
                  final isSelected = _selectedDays[index];

                  Color buttonColor = Colors.white;
                  Color textColor = const Color(0xFF9CA3AF);
                  Border border = Border.all(color: const Color(0xFFE5E7EB), width: 1.0);

                  if (isSelected) {
                    buttonColor = const Color(0xFFFF5722);
                    textColor = Colors.white;
                    border = Border.all(color: Colors.transparent, width: 0);
                  }

                  return InkWell(
                    onTap: () => setState(() => _selectedDays[index] = !_selectedDays[index]),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: buttonColor,
                        shape: BoxShape.circle,
                        border: border,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dayStr,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500, // 미선택도 정렬감 있게 500 세팅
                            color: textColor
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Spacer(flex: 2),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: InkWell(
                onTap: _isSaveButtonEnabled ? _handleSave : null,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isSaveButtonEnabled ? const Color(0xFF1A1A1A) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '완료',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerWheel({required FixedExtentScrollController controller, required List<String> items, required int selectedIndex, required ValueChanged<int> onChanged}) {
    return ListWheelScrollView.useDelegate(
      itemExtent: 44,
      physics: const FixedExtentScrollPhysics(),
      controller: controller,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: items.length,
        builder: (context, index) {
          final isTarget = (index == selectedIndex);
          return Center(child: Text(items[index], style: TextStyle(fontSize: 22, fontWeight: isTarget ? FontWeight.bold : FontWeight.w400, color: isTarget ? Colors.black : Colors.grey.shade400)));
        },
      ),
    );
  }
}