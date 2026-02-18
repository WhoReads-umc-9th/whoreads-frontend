import 'package:flutter/material.dart';
import '../../models/dna_models.dart';
import '../celebrities/celebrities_book_page.dart'; // 상세 페이지 import

class DnaResultPage extends StatelessWidget {
  final DnaResult result;

  const DnaResultPage({super.key, required this.result});

  // [로직] 따옴표를 포함한 문자열 추출
  String _extractContent(String fullText) {
    final RegExp regex = RegExp(r"'(.*?)'");
    final match = regex.firstMatch(fullText);
    return match?.group(0) ?? fullText;
  }

  @override
  Widget build(BuildContext context) {
    // 직업 태그 처리
    final String jobTitle = result.jobTags.isNotEmpty ? result.jobTags.first : '';
    // 헤드라인 추출
    final String coreHeadline = _extractContent(result.headline);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '독서 DNA 테스트 결과',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // -------------------------------------------------------
            // [1] 상단 ~ 중간 (스크롤 가능 영역, 남은 공간 모두 차지)
            // -------------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // 1-1. 헤드라인 (상단 배치)
                    const Text(
                      "지금 당신은",
                      style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      coreHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6A00),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "독서를 하는 사람입니다",
                      style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 40),

                    // 1-2. 설명 텍스트 (화면 중앙 느낌으로 배치)
                    // 내용이 많으면 스크롤되고, 적으면 헤드라인과 인물 사이에 위치함
                    Column(
                      children: result.description.map((desc) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          desc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.6
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // -------------------------------------------------------
            // [2] 하단 고정 영역 (인물 정보 + 버튼)
            // -------------------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
              decoration: BoxDecoration(
                color: Colors.white
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 차지
                children: [
                  // 2-1. 인물 소개 라벨
                  const Text(
                    "이 유형에 속하는 인물",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // 2-2. 원형 이미지
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                      image: result.imageUrl.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(result.imageUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: result.imageUrl.isEmpty
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // 2-3. 인물 이름
                  Text(
                    "$jobTitle ${result.celebrityName}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 2-4. 하단 버튼 (페이지 이동)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // [페이지 이동 로직]
                        // API에서 받은 celebrityId가 필요합니다.
                        // DnaResult 모델에 id 필드가 없으면 임시로 1 등을 넣거나 모델을 수정해야 합니다.
                        // 예시: result.celebrityId (모델에 추가 필요)

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CelebritiesBookPage(
                              celebrityId: 1, // TODO: 실제 API에서 받은 ID로 교체 필요
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '${result.celebrityName}의 추천 도서 확인하기',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}