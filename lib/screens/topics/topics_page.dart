import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
// 🌟 [수정됨] 상세 페이지 import 주석 해제
import '../books/BookDetailPage.dart';
import 'package:whoreads/screens/topics/top_20_books_page.dart';

import '../../core/auth/token_storage.dart';
import '../celebrities/celebrities_page.dart';
import '../my_library/my_library_page.dart';
import '../profile.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key});

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  static const String _baseUrl = 'http://43.201.122.162';

  final ScrollController _scrollController = ScrollController();

  String selectedCategory = '전체';
  bool isDropdownOpen = false;
  bool isLoading = false;

  List<dynamic> banners = [];
  List<dynamic> books = [];

  final Map<String, String?> categoryMap = {
    '전체': null,
    '사회·역사': 'SOCIETY_HISTORY',
    '자기계발·심리': 'SELF_IMPROVEMENT',
    '문학': 'LITERATURE',
    '과학': 'SCIENCE',
    '경제·경영': 'ECONOMY',
    '인문': 'HUMANITIES',
    '예술': 'ART',
  };

  List<String> get categoryKeys => categoryMap.keys.toList();

  @override
  void initState() {
    super.initState();
    _fetchTopicsData();
  }

  Future<void> _fetchTopicsData() async {
    setState(() => isLoading = true);

    try {
      final token = await TokenStorage.getAccessToken();
      final categoryTag = categoryMap[selectedCategory];

      Uri uri = Uri.parse('$_baseUrl/api/topics');
      if (categoryTag != null) {
        uri = uri.replace(queryParameters: {'category': categoryTag});
      }

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final String bodyString = utf8.decode(response.bodyBytes);
        final dynamic decoded = jsonDecode(bodyString);

        List<dynamic> newBooks = [];

        if (decoded is List && decoded.isNotEmpty) {
          if (decoded[0] is Map && decoded[0].containsKey('books')) {
            newBooks = decoded[0]['books'];
          } else {
            newBooks = decoded;
          }
        }
        else if (decoded is Map && decoded.containsKey('books')) {
          newBooks = decoded['books'];
        }

        setState(() {
          books = newBooks;
          if (banners.isEmpty) _setMockBanners();
        });
      } else {
        debugPrint('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network/Parsing Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _setMockBanners() {
    banners = [
      {
        "title": "WhoReads의 유명인들이\n가장 많이 추천한 책 TOP20",
        "subtitle": "가장 많이 언급된 책은 무엇일까요?",
        "count": 20,
        "images": [
          "https://i.pravatar.cc/150?img=1",
          "https://i.pravatar.cc/150?img=2",
          "https://i.pravatar.cc/150?img=5",
        ]
      },
      {
        "title": "각 분야의 유명인들이\n사회를 이해하기 위해 읽은 책",
        "subtitle": "세상은 왜 이렇게 돌아갈까요?",
        "count": 15,
        "images": [
          "https://i.pravatar.cc/150?img=8",
          "https://i.pravatar.cc/150?img=9",
          "https://i.pravatar.cc/150?img=10",
        ]
      },
    ];
  }

  void onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      isDropdownOpen = false;
    });
    _fetchTopicsData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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

      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "이런 주제 어때요?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.7),
                    padEnds: false,
                    itemCount: banners.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          if (index == 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Top20BooksPage()),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: _TopicBannerCard(banner: banners[index]),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                      GestureDetector(
                        onTap: () {
                          setState(() => isDropdownOpen = !isDropdownOpen);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            children: [
                              Text(
                                isDropdownOpen ? '접기' : '카테고리',
                                style: const TextStyle(
                                  fontSize: 13,
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

                const SizedBox(height: 16),

                if (isLoading)
                  const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00))),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 24,
                        childAspectRatio: 0.55,
                      ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return GestureDetector(
                          // 🌟 [수정됨] 클릭 시 책 상세 페이지로 이동
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailPage(
                                  bookId: book['id'] ?? book['book_id'],
                                ),
                              ),
                            ).then((_) {
                              // 뒤로가기 했을 때 상태 업데이트 (필요시)
                              _fetchTopicsData();
                            });
                          },
                          child: _TopicBookCard(book: book),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          if (isDropdownOpen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => isDropdownOpen = false),
                    child: Container(color: Colors.transparent),
                  ),
                  Positioned(
                    top: 270,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = (constraints.maxWidth - (8 * 3)) / 4;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categoryKeys.map((category) {
                                final isSelected = category == selectedCategory;
                                return GestureDetector(
                                  onTap: () => onCategorySelected(category),
                                  child: Container(
                                    width: itemWidth,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFB9566)
                                            : const Color(0xFFE5E7EB),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? const Color(0xFFFB9566)
                                            : Colors.black87,
                                        fontWeight:
                                        isSelected ? FontWeight.bold : FontWeight.normal,
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
            ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: const Color(0xFFF84E00),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CelebritiesPage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyLibraryPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '인물'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '내 서재'),
          BottomNavigationBarItem(icon: Icon(Icons.topic), label: '주제'),
        ],
      ),
    );
  }
}

class _TopicBannerCard extends StatelessWidget {
  final dynamic banner;
  const _TopicBannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final String title = banner['title'] ?? '';
    final String subtitle = banner['subtitle'] ?? '';
    final int count = banner['count'] ?? 0;
    final List<dynamic> images = banner['images'] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6A00), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 80,
                height: 30,
                child: Stack(
                  children: List.generate(images.take(3).length, (index) {
                    return Positioned(
                      left: index * 20.0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: DecorationImage(
                            image: NetworkImage(images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Text(
                "${count}권",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _TopicBookCard extends StatelessWidget {
  final dynamic book;
  const _TopicBookCard({required this.book});

  Color _getGenreColor(String genre) {
    if (genre.contains('사회') || genre.contains('역사')) return const Color(0xFFF89B05);
    if (genre.contains('자기계발') || genre.contains('심리')) return const Color(0xFF0881F9);
    if (genre.contains('문학')) return const Color(0xFFF84E00);
    if (genre.contains('과학')) return const Color(0xFF1BA430);
    if (genre.contains('경제') || genre.contains('경영')) return const Color(0xFF9747FF);
    if (genre.contains('에세이') || genre.contains('회고')) return const Color(0xFFFB9566);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final String genre = book['genre'] ?? '기타';
    final String title = book['title'] ?? '';
    final String coverUrl = book['cover_url'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.book, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getGenreColor(genre),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            genre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}