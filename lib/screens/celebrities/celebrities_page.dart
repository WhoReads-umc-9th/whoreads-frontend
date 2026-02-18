import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;

import '../my_library/my_library_page.dart';
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
    '전체': null,
    '가수': 'SINGER',
    '배우': 'ACTOR',
    '유튜버': 'YOUTUBER',
    '스포츠선수': 'ATHLETE',
    '영화감독': 'MOVIE_DIRECTOR',
    '작가': 'WRITER',
    '교수': 'PROFESSOR',
    '기업가': 'ENTREPRENEUR',
    '아이돌': 'IDOL',
    '코미디언': 'COMEDIAN',
  };

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

      /// ================= AppBar =================
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: SvgPicture.asset(
          'assets/images/logo.svg',
          height: 18, // 높이를 지정하면 비율에 맞춰 너비가 자동 조절됩니다.
          // 만약 로고 색상을 강제로 주황색으로 바꿔야 한다면 아래 주석 해제
          // colorFilter: const ColorFilter.mode(Color(0xFFFF6A00), BlendMode.srcIn),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),

      /// ================= Body =================
      body: Column(
        children: [
          /// ===== 카테고리 바 =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _SelectedCategoryChip(text: selectedCategory),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => isDropdownOpen = !isDropdownOpen);
                  },
                  child: Row(
                    children: [
                      const Text('카테고리'),
                      Icon(
                        isDropdownOpen
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// ===== 드롭다운 =====
          if (isDropdownOpen)
            Container(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryMap.keys.map((category) {
                  final isSelected = category == selectedCategory;
                  return GestureDetector(
                    onTap: () => onCategorySelected(category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                          isSelected ? Colors.orange : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(category),
                    ),
                  );
                }).toList(),
              ),
            ),

          /// ===== 인물 Grid =====
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.62,
                ),
                itemCount: celebrities.length,
                itemBuilder: (context, index) {
                  final celeb = celebrities[index];
                  return _CelebrityCard(celeb: celeb);
                },
              ),
            ),
          ),
        ],
      ),

      /// ================= Bottom Tab =================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            // 현재 페이지이므로 아무것도 안 함 (또는 새로고침)
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyLibraryPage()),
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

/// ================= 선택된 카테고리 Chip =================
class _SelectedCategoryChip extends StatelessWidget {
  final String text;

  const _SelectedCategoryChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

/// ================= 인물 카드 =================
class _CelebrityCard extends StatelessWidget {
  final dynamic celeb;

  const _CelebrityCard({required this.celeb});

  @override
  Widget build(BuildContext context) {
    final List tags = celeb['job_tags'] ?? [];

    // [수정됨] GestureDetector로 감싸서 클릭 이벤트 처리
    return GestureDetector(
      onTap: () {
        debugPrint('인물 클릭: ${celeb['name']} (ID: ${celeb['id']})');

        // 상세 페이지로 이동하며 ID 전달
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CelebritiesBookPage(
              celebrityId: celeb['id'], // API에서 받은 id 전달
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
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
          const SizedBox(height: 6),
          Text(
            celeb['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          /// 태그 레이아웃
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.take(2).map<Widget>((tag) {
                  return Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(fontSize: 11),
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