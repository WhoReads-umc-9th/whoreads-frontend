import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyDatePicker {
  static void show(
    BuildContext context, {
    required String initialYear,
    required String initialMonth,
    required Function(String year, String month) onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DatePickerWidget(
        initialYear: initialYear,
        initialMonth: initialMonth,
        onConfirm: onConfirm,
      ),
    );
  }
}

class _DatePickerWidget extends StatefulWidget {
  final String initialYear;
  final String initialMonth;
  final Function(String year, String month) onConfirm;

  const _DatePickerWidget({
    required this.initialYear,
    required this.initialMonth,
    required this.onConfirm,
  });

  @override
  State<_DatePickerWidget> createState() => _DatePickerWidgetState();
}

class _DatePickerWidgetState extends State<_DatePickerWidget> {
  late String selectedYear;
  late String selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialYear;
    selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250, // 높이 조절
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)), // 더 둥글게
      ),
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. 중앙 주황색 하이라이트 박스 (고정)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF5722),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // 2. 실제 피커
                Row(
                  children: [
                    _buildPicker(
                      ["2024", "2025", "2026", "2027"],
                      selectedYear,
                      (val) => setState(() => selectedYear = val),
                    ),
                    _buildPicker(
                      List.generate(12, (i) => "${i + 1}"),
                      selectedMonth,
                      (val) => setState(() => selectedMonth = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildPicker(
    List<String> items,
    String initialValue,
    Function(String) onChanged,
  ) {
    final int initialIndex = items.indexOf(initialValue);
    return Expanded(
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(
          initialItem: initialIndex != -1 ? initialIndex : 0,
        ),
        itemExtent: 48,
        // 💡 핵심: 기본 회색 선 제거
        selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
          background: Colors.transparent,
        ),
        onSelectedItemChanged: (index) => onChanged(items[index]),
        children: items.map((item) {
          return Center(
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // 취소 버튼
        Expanded(
          child: SizedBox(
            height: 51,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(10),
                side: const BorderSide(color: Color(0xFFA1A4AC)), // 연한 회색 테두리
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "취소",
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 확인 버튼
        Expanded(
          child: SizedBox(
            height: 51,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(selectedYear, selectedMonth);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(10),
                backgroundColor: const Color(0xFF1C1C22), // 짙은 네이비/블랙
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                "확인",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
