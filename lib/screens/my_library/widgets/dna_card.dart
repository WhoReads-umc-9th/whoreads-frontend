import 'package:flutter/material.dart';

class DnaCard extends StatelessWidget {
  const DnaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: DNA 테스트 화면 이동
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
        ),
        child: Row(
          children: const [
            Icon(Icons.science_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '독서 DNA 테스트\n당신의 선택 방식에 맞는 독서 유형을 알려드려요!',
              ),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}