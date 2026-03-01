import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dna_test_page.dart';

class DnaTestDialog extends StatelessWidget {
  const DnaTestDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // Center + Container 대신 Dialog 위젯 사용 (Material 테마 적용 및 오류 방지)
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24), // 좌우 여백
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 닫기 버튼 및 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 닫기 아이콘 크기(28)와 동일하게 맞춰서 제목을 정확히 중앙 정렬
                const SizedBox(width: 28),
                const Text(
                  '독서 DNA 테스트',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 설명 텍스트
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                children: [
                  TextSpan(text: '몇 가지 질문에 답하면,\n당신의 선택 방식에 맞는 '),
                  TextSpan(
                    text: '독서 유형',
                    style: TextStyle(color: Color(0xFFFF6A00), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '과\n그 유형에 맞는 '),
                  TextSpan(
                    text: '유명인',
                    style: TextStyle(color: Color(0xFFFF6A00), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '을 보여드려요!'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 중앙 SVG 이미지 2개 겹치기
            Stack(
              alignment: Alignment.center,
              children: [
                // 1. 밑에 깔리는 이미지
                SvgPicture.asset(
                  'assets/images/dna_test1.svg',
                  height: 180,
                ),
                // 2. 그 위에 덮어지는 이미지
                SvgPicture.asset(
                  'assets/images/dna_test2.svg',
                  height: 180,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 하단 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  debugPrint("버튼 눌림!");

                  // 화면 전환을 위해 Navigator 객체 캐싱
                  final navigator = Navigator.of(context);

                  // 1. 다이얼로그 닫기
                  navigator.pop();

                  // 2. 페이지 이동
                  navigator.push(
                    MaterialPageRoute(builder: (context) => const DnaTestPage()),
                  );
                },
                child: const Text(
                  '1분 만에 확인하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}