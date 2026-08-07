import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../books/BookDetailPage.dart';
import 'package:whoreads/screens/topics/topic_banner_page.dart';

import '../../core/network/api_client.dart';
import '../celebrities/celebrities_page.dart';
import '../my_library/my_library_page.dart';
import '../notification_screen.dart';
import '../users/profile.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key});

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  final ScrollController _scrollController = ScrollController();

  String selectedCategory = '전체';
  bool isDropdownOpen = false;
  bool isLoading = false;

  List<dynamic> rawTopicsData = [];
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
      final categoryTag = categoryMap[selectedCategory];
      final response = await ApiClient.dio.get(
        '/topics',
        queryParameters: categoryTag == null ? null : {'category': categoryTag},
      );

      if (response.statusCode == 200) {
        final dynamic decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;

        List<dynamic> topicList = [];

        if (decoded is List) {
          topicList = decoded;
        } else if (decoded is Map && decoded['result'] is List) {
          topicList = decoded['result'];
        }

        rawTopicsData = topicList;

        await _buildBannersFromApi();

        List<dynamic> newBooks = [];
        if (topicList.isNotEmpty) {
          for (var item in topicList) {
            if (item is Map && item['books'] is List) {
              newBooks.addAll(item['books']);
            }
          }
        }

        setState(() {
          books = newBooks;
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

  Future<void> _buildBannersFromApi() async {
    List<dynamic> generatedBanners = [];

    for (int i = 0; i < 6; i++) {
      final meta = _getBannerMeta(i);
      final String theme = meta['theme'];

      List<String> previewImages = [];
      int actualCount = meta['defaultCount'];

      try {
        final response = await ApiClient.dio.get(
          '/books/themes/$theme',
          queryParameters: {'limit': 20},
        );

        if (response.statusCode == 200) {
          final decoded = response.data is String
              ? jsonDecode(response.data as String)
              : response.data;

          List<dynamic> themeBooks = [];
          if (decoded is List) {
            themeBooks = decoded;
          } else if (decoded is Map && decoded['result'] is List) {
            themeBooks = decoded['result'];
          }

          actualCount = themeBooks.length;

          for (var b in themeBooks) {
            if (b is Map && b['cover_url'] != null && (b['cover_url'] as String).isNotEmpty) {
              previewImages.add(b['cover_url'] as String);
              if (previewImages.length >= 3) break;
            }
          }
        }
      } catch (e) {
        debugPrint('Banner fetch error for theme $theme: $e');
      }

      generatedBanners.add({
        "theme": theme,
        "title": meta['title'],
        "subtitle": meta['subtitle'],
        "description": meta['description'],
        "count": actualCount,
        "images": previewImages,
      });
    }

    if (mounted) {
      setState(() {
        banners = generatedBanners;
      });
    }
  }

  Map<String, dynamic> _getBannerMeta(int index) {
    final List<Map<String, dynamic>> metaList = [
      {
        "title": "WhoReads의 유명인들이\n가장 많이 추천한 책 TOP20",
        "subtitle": "가장 많이 언급된 책은 무엇일까요?",
        "description": "WhoReads에 모인 수많은 유명인 추천 중,\n가장 많이 언급되고 반복해서 추천된 책 TOP 20을 선정했습니다.",
        "defaultCount": 20,
        "theme": "TOP_20",
      },
      {
        "title": "각 분야의 유명인들이\n사회를 이해하기 위해 읽은 책",
        "subtitle": "세상은 왜 이렇게 돌아갈까요?",
        "description": "복잡한 현대 사회와 역사의 흐름을 파악하기 위해\n각 분야의 전문가와 유명인들이 읽었던 추천 도서입니다.",
        "defaultCount": 20,
        "theme": "SOCIETY",
      },
      {
        "title": "각 분야의 유명인들이\n인간을 이해하기 위해 읽은 책",
        "subtitle": "인간은 왜 그렇게 행동할까요?",
        "description": "심리학과 인문학을 통찰하여\n사람의 마음과 행동의 본질을 다룬 도서 목록입니다.",
        "defaultCount": 20,
        "theme": "HUMAN_UNDERSTANDING",
      },
      {
        "title": "각 분야의 유명인들의\n사고 방식을 바꾼 책",
        "subtitle": "생각하는 방식이 달라지는 순간",
        "description": "고정관념을 깨고 새로운 관점을 제시해 준\n명사들의 추천 서적입니다.",
        "defaultCount": 20,
        "theme": "MINDSET",
      },
      {
        "title": "각 분야의 유명인들이\n삶의 방향을 고민할 때 읽은 책",
        "subtitle": "나는 어떻게 살아야 할까?",
        "description": "치열한 고민 끝에 삶의 이정표가 되어 준\n유명인들의 인생 책 모음입니다.",
        "defaultCount": 20,
        "theme": "LIFE_DIRECTION",
      },
      {
        "title": "각 분야의 유명인들이\n인생의 전환점에서 만난 책",
        "subtitle": "인생이 바뀌는 순간, 곁에 있던 책",
        "description": "커다란 터닝포인트를 맞이했을 때\n깊은 영감을 선사했던 추천 도서들입니다.",
        "defaultCount": 20,
        "theme": "TURNING_POINT",
      },
    ];

    return metaList[index % metaList.length];
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
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationPage(),
                ),
              );
            },
          ),
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
                  child: PageView(
                    controller: PageController(viewportFraction: 0.7),
                    padEnds: false,
                    children: banners.map((banner) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopicBannerPage(
                                theme: banner['theme'],
                                title: banner['title'],
                                description: banner['description'],
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: _TopicBannerCard(banner: banner),
                        ),
                      );
                    }).toList(),
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
                        childAspectRatio: 0.48,
                      ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailPage(
                                  bookId: book['id'] ?? book['book_id'],
                                ),
                              ),
                            ).then((_) {
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
                  children: List.generate(
                    images.isNotEmpty ? images.take(3).length : 3,
                        (index) {
                      final bool hasImage = images.length > index;
                      final String? imgUrl = hasImage ? images[index] : null;

                      return Positioned(
                        left: index * 20.0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipOval(
                            child: imgUrl != null && imgUrl.isNotEmpty
                                ? Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.book,
                                size: 16,
                                color: Color(0xFFFF6A00),
                              ),
                            )
                                : const Icon(
                              Icons.book,
                              size: 16,
                              color: Color(0xFFFF6A00),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
              child: coverUrl.isNotEmpty
                  ? Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.book, color: Colors.grey),
                  ),
                ),
              )
                  : Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.book, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),

        Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getGenreColor(genre),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                genre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}