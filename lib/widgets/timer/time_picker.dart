import 'package:flutter/material.dart';

class TimePickerWidget extends StatefulWidget {
  final Function(int) onTimeSelected;
  const TimePickerWidget({super.key, required this.onTimeSelected});

  @override
  State<TimePickerWidget> createState() => _TimePickerWidgetState();
}

class _TimePickerWidgetState extends State<TimePickerWidget> {
  final List<int> _minutes = List.generate(25, (index) => index * 5);
  int _selectedIndex = 18; // 초기값 90분

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 배경: 주황색 테두리 박스 (고정)
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF5722), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // 2. 휠 스크롤 뷰 (숫자만 돌아감)
          ListWheelScrollView.useDelegate(
            itemExtent: 50,
            physics: const FixedExtentScrollPhysics(),
            overAndUnderCenterOpacity: 0.3, // 중앙 외 아이템 투명도
            perspective: 0.005,
            onSelectedItemChanged: (index) {
              setState(() => _selectedIndex = index);
              widget.onTimeSelected(_minutes[index]);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: _minutes.length,
              builder: (context, index) {
                return Center(
                  child: Padding(
                    // '분' 글자 자리를 비워두기 위해 오른쪽 패딩 추가
                    padding: const EdgeInsets.only(right: 30),
                    child: Text(
                      '${_minutes[index]}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: _selectedIndex == index
                            ? FontWeight.bold
                            : FontWeight.w400,
                        color: _selectedIndex == index
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. '분' 텍스트 고정 (주황색 박스 안 우측에 배치)
          IgnorePointer(
            // 클릭 방해 안 되게 설정
            child: Container(
              height: 50,
              alignment: const Alignment(0.15, 0), // 중앙에서 약간 오른쪽
              child: const Text(
                '분',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // 4. 상하단 그라데이션 (투명해지며 사라지는 효과)
          _buildGradientMask(),
        ],
      ),
    );
  }

  // 투명 효과를 주는 마스크 위젯
  Widget _buildGradientMask() {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.white, Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
