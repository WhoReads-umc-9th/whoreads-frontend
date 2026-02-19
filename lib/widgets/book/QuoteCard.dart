import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class QuoteCard extends StatelessWidget {
  final String profileImage;
  final String name;
  final String job;
  final String quote;
  final String source;
  final String? sourceUrl; // 외부 링크 이동을 위해 추가

  const QuoteCard({
    Key? key,
    required this.profileImage,
    required this.name,
    required this.job,
    required this.quote,
    required this.source,
    this.sourceUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 배경을 흰색으로 하고, 전체 카드 여백을 설정
    return Container(
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 좌측: 프로필 이미지
          CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(profileImage),
            backgroundColor: Colors.grey[200],
            onBackgroundImageError: (_, __) => const Icon(Icons.person),
          ),

          const SizedBox(width: 12), // 이미지와 텍스트 사이 간격

          // 2. 우측: 이름, 직업, 인용문, 출처 (모두 같은 왼쪽 라인에서 시작)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌟 [수정된 부분] 이름과 직업을 Column으로 세로 배치
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                // 직업 태그가 있을 때만 렌더링
                if (job.isNotEmpty) ...[
                  const SizedBox(height: 4), // 이름과 태그 사이의 간격
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // 인용문 텍스트 (아이콘 없이 깔끔하게 텍스트만)
                Text(
                  quote,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151), // 진한 회색
                    height: 1.6, // 가독성을 위한 줄간격
                  ),
                ),

                const SizedBox(height: 12),

                // 출처 링크 (우측 정렬)
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () async {
                      // sourceUrl이 있으면 해당 링크로 이동
                      if (sourceUrl != null && sourceUrl!.isNotEmpty) {
                        final uri = Uri.parse(sourceUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    child: Text(
                      source,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF84E00),
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFF84E00), // 밑줄도 동일한 주황색
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
