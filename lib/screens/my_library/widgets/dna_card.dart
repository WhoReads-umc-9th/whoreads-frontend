import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DnaCard extends StatelessWidget {
  const DnaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // 카드 내부 여백
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 둥근 모서리
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // 은은한 그림자
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 텍스트 왼쪽 정렬
        children: [
          /// 1. 상단 헤더 (아이콘 + 제목 + 화살표)
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/dna_book.svg', // SVG 파일 경로
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 8), // 아이콘과 제목 사이 간격
              const Text(
                '독서 DNA 테스트',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937), // 진한 회색 (거의 검정)
                ),
              ),
              const Spacer(), // 화살표를 오른쪽 끝으로 밀어버림
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9CA3AF), // 연한 회색
                size: 24,
              ),
            ],
          ),

          const SizedBox(height: 12), // 상단과 하단 사이 간격

          /// 2. 하단 설명 텍스트 (RichText로 색상 혼합)
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF374151), // 기본 글자색 (진한 회색)
                height: 1.5, // 줄 간격 (가독성 높임)
                // 만약 앱 전체 폰트가 적용 안 되어 있다면 여기에 fontFamily 추가 필요
                fontFamily: 'Pretendard',
              ),
              children: [
                TextSpan(text: '당신의 선택 방식에 맞는 '),
                TextSpan(
                  text: '독서 유형',
                  style: TextStyle(
                    color: Color(0xFFF84E00), // 요청하신 주황색
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: '과\n그 유형에 맞는 '), // \n으로 줄바꿈
                TextSpan(
                  text: '유명인',
                  style: TextStyle(
                    color: Color(0xFFF84E00), // 요청하신 주황색
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: '을 보여드려요!'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}