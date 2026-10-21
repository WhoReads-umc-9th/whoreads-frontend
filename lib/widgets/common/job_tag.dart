import 'package:flutter/material.dart';

class JobTag extends StatelessWidget {
  const JobTag(this.label, {super.key});

  final String label;

  static const textStyle = TextStyle(
    fontSize: 12,
    height: 1.3,
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  static Color colorFor(String label) =>
      const {
        '가수': Color(0xFF0881F9),
        '배우': Color(0xFF0F09B2),
        '기업가': Color(0xFF9747FF),
        '학자': Color(0xFF1BA430),
        '스포츠선수': Color(0xFF7C98FD),
        '아이돌': Color(0xFFFF95C0),
        '유튜버': Color(0xFF0DA7FA),
        '아나운서': Color(0xFFF89B05),
        '개그맨': Color(0xFF179B7C),
        '작가': Color(0xFF6A8CC7),
        '영화감독': Color(0xFF8FBA21),
        '교수': Color(0xFF350AC3),
        '요리사': Color(0xFFB98F82),
        '뮤지컬배우': Color(0xFFE8C252),
        '강사': Color(0xFF6D524D),
        '프로파일러': Color(0xFF295E55),
        '문학평론가': Color(0xFFF84E00),
        '언론비평가': Color(0xFFF84E00),
        '과학관장': Color(0xFF064D93),
        '번역가': Color(0xFFCF33D2),
        '작사가': Color(0xFFF28789),
        '생물학자': Color(0xFFC0ACEC),
        '정치인': Color(0xFF7C8A98),
      }[label] ??
      Colors.grey;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: colorFor(label),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: textStyle,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
