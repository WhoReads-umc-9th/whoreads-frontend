import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:whoreads/screens/topics/topics_page.dart';
import '../my_library/my_library_page.dart';
import '../profile.dart';
import 'celebrities_book_page.dart'; // [중요] 방금 만든 페이지 import 확인해주세요!

class CelebritiesPage extends StatefulWidget {
  const CelebritiesPage({super.key});

  @override
  State<CelebritiesPage> createState() => _CelebritiesPageState();
}

class _CelebritiesPageState extends State<CelebritiesPage> {
  final ScrollController _scrollController = ScrollController();

  String selectedCategory = '전체';
  bool isDropdownOpen = false;

  static const String _baseUrl = 'http://43.201.122.162';

  List<dynamic> celebrities = [];
  bool isLoading = false;

  /// 카테고리 매핑 (UI 텍스트 → API tag)
  final Map<String, String?> categoryMap = {
    '전체': null, '학자': 'SCHOLAR', '스포츠선수': 'ATHLETE', '과학관장': 'SCIENCE_DIRECTOR',
    '가수': 'SINGER', '아나운서': 'ANNOUNCER', '개그맨': 'COMEDIAN', '영화평론가': 'MOVIE_CRITIC',
    '영화감독': 'MOVIE_DIRECTOR', '번역가': 'TRANSLATOR', '프로파일러': 'PROFILER', '정치인': 'POLITICIAN',
    '강사': 'INSTRUCTOR', '대통령': 'PRESIDENT', '배우': 'ACTOR', '뮤지컬배우': 'MUSICAL_ACTOR',
    '작사가': 'LYRICIST', '생물학자': 'BIOLOGIST', '교수': 'PROFESSOR', '기업가': 'ENTREPRENEUR',
    '유튜버': 'YOUTUBER', '요리사': 'CHEF', '언론비평가': 'MEDIA_CRITIC', '작가': 'WRITER',
    '아이돌': 'IDOL', '문학평론가': 'LITERARY_CRITIC',
  };

  // 맵의 키만 리스트로 변환 (순서 보장용)
  List<String> get categoryKeys => categoryMap.keys.toList();

  @override
  void initState() {
    super.initState();
    fetchCelebrities();
  }

  Future<void> fetchCelebrities() async {
    setState(() => isLoading = true);

    final tag = categoryMap[selectedCategory];

    final uri = tag == null
        ? Uri.parse('$_baseUrl/api/celebrities')
        : Uri.parse('$_baseUrl/api/celebrities')
        .replace(queryParameters: {'tag': tag});

    try {
      final response = await http.get(uri);

      debugPrint('REQUEST URI: $uri');
      debugPrint('STATUS CODE: ${response.statusCode}');
      // debugPrint('RESPONSE BODY: ${response.body}'); // 로그 너무 길면 주석 처리

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          celebrities = decoded;
        });
      } else {
        debugPrint('API 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('네트워크 에러: $e');
    }

    setState(() => isLoading = false);
  }

  void onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      isDropdownOpen = false;
    });
    fetchCelebrities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: SvgPicture.asset('assets/images/logo.svg', height: 18),
        actions: [
          const Icon(Icons.notifications_none, color: Colors.black),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack( // 드롭다운이 컨텐츠 위에 떠야 하므로 Stack 사용
        children: [
          Column(
            children: [
              /// ===== 상단 카테고리 바 =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // [왼쪽] 선택된 카테고리 (주황색)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB9566),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        selectedCategory,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // [오른쪽] 접기/펼치기 버튼 (회색)
                    GestureDetector(
                      onTap: () {
                        setState(() => isDropdownOpen = !isDropdownOpen);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6), // 연한 회색 배경
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isDropdownOpen ? '접기' : '카테고리', // 텍스트 변경
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isDropdownOpen
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              /// ===== 인물 리스트 (기존 코드) =====
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.52,
                  ),
                  itemCount: celebrities.length,
                  itemBuilder: (context, index) {
                    // ... (기존 _CelebrityCard 호출 코드)
                    return _CelebrityCard(celeb: celebrities[index]);
                  },
                ),
              ),
            ],
          ),

          /// ===== [드롭다운 오버레이] =====
          if (isDropdownOpen)
            Positioned(
              top: 60, // 상단 바 높이만큼 띄움
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                // 화면 높이의 일부까지만 차지하도록 제한 (스크롤 가능하게)
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 한 줄에 4개 배치하기 위한 너비 계산
                      // (전체너비 - (간격 * 3)) / 4
                      final itemWidth = (constraints.maxWidth - (8 * 3)) / 4;

                      return Wrap(
                        spacing: 8, // 가로 간격
                        runSpacing: 8, // 세로 간격
                        children: categoryKeys.map((category) {
                          final isSelected = category == selectedCategory;
                          return GestureDetector(
                            onTap: () => onCategorySelected(category),
                            child: Container(
                              width: itemWidth, // [핵심] 4등분 너비 강제 지정
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFB9566)
                                      : const Color(0xFFE5E7EB), // 선택 안됨: 연한 회색 테두리
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12, // 글자 크기 조정 (칸에 맞게)
                                  color: isSelected ? const Color(0xFFFB9566) : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),

      /// ================= Bottom Tab =================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFFF84E00),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyLibraryPage())
            );
          }else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TopicsPage())
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '인물',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: '내 서재',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.topic),
            label: '주제',
          ),
        ],
      ),
    );
  }
}

/// ================= 인물 카드 =================
/// ================= 인물 카드 =================
class _CelebrityCard extends StatelessWidget {
  final dynamic celeb;

  const _CelebrityCard({required this.celeb});

  /// 직업별 색상 매핑 함수
  Color _getJobColor(String job) {
    const Map<String, int> jobColorMap = {
      '가수': 0xFF0881F9,
      '배우': 0xFF0F09B2,
      '기업가': 0xFF9747FF,
      '학자': 0xFF1BA430,
      '스포츠선수': 0xFF7C98FD,
      '아이돌': 0xFFFF95C0,
      '유튜버': 0xFF0DA7FA,
      '아나운서': 0xFFF89B05,
      '개그맨': 0xFF179B7C,
      '영화평론가': 0xFF9B4E17,
      '작가': 0xFF6A8CC7,
      '영화감독': 0xFF8FBA21,
      '교수': 0xFF350AC3,
      '요리사': 0xFFB98F82,
      '뮤지컬배우': 0xFFE8C252,
      '강사': 0xFF6D524D,
      '프로파일러': 0xFF295E55,
      '문학평론가': 0xFFF84E00,
      '과학관장': 0xFF064D93,
      '언론비평가': 0xFF93064D,
      '번역가': 0xFFCF33D2,
      '작사가': 0xFFF28789,
      '생물학자': 0xFFC0ACEC,
      '대통령': 0xFF373638,
      '정치인': 0xFF7C8A98,
    };

    // 맵에 없으면 기본 회색 반환
    final hexValue = jobColorMap[job];
    return hexValue != null ? Color(hexValue) : Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final List tags = celeb['job_tags'] ?? [];

    return GestureDetector(
      onTap: () {
        debugPrint('인물 클릭: ${celeb['name']} (ID: ${celeb['id']})');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CelebritiesBookPage(
              celebrityId: celeb['id'],
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                celeb['image_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 이름
          Text(
            celeb['name'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center, // 텍스트 자체도 가운데 정렬
          ),
          const SizedBox(height: 6),

          /// [수정 3] 태그 레이아웃 (색상 적용 및 가운데 정렬)
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                alignment: WrapAlignment.center, // Wrap 내부 아이템 가운데 정렬
                spacing: 6,
                runSpacing: 4,
                children: tags.take(2).map<Widget>((tag) {
                  final color = _getJobColor(tag); // 색상 가져오기

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4
                    ),
                    decoration: BoxDecoration(
                      color: color, // 직업별 색상 적용
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white, // 배경이 진하므로 글자는 흰색
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}