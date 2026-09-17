import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoreads/screens/topics/topic_banner_page.dart';

import '../../core/network/api_client.dart';
import '../books/BookDetailPage.dart';
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

  bool isBooksLoading = false;
  bool isBannersLoading = false;
  bool isLoadingMore = false;

  // 서버 페이지는 무조건 20개씩 조회
  static const int pageSize = 20;

  // 현재 선택된 카테고리에 최소 확보할 책 개수
  static const int minimumVisibleBooks = 20;

  int currentPage = 0;
  bool hasNext = true;

  Map<String, List<dynamic>> books = {};
  List<dynamic> allBooks = [];
  List<dynamic> selectBooks = [];

  List<dynamic> banners = [];

  final Map<String, String?> categoryMap = {
    '전체': null,
    '사회·역사': '사회·역사',
    '자기계발·심리': '자기계발·심리',
    '문학': '문학',
    '과학': '과학·기술',
    '경제·경영': '경제·경영·커리어',
    '에세이': '에세이·회고',
    '인문': '인문·철학',
  };

  List<String> get categoryKeys => categoryMap.keys.toList();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _initializeBooks();
    _buildBannersFromApi();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

  // =========================================================
  // 최초 책 조회
  // =========================================================

  Future<void> _initializeBooks() async {
    // 최초 page=0, size=20
    await _fetchTopicsData(reset: true);

    // 전체에서도 최소 20개 확보
    await _ensureMinimumBooks();
  }

  // =========================================================
  // 스크롤
  // =========================================================

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (isBooksLoading ||
        isLoadingMore ||
        !hasNext) {
      return;
    }

    final position = _scrollController.position;

    // 바닥 300px 전에 다음 페이지
    if (position.pixels >=
        position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (isBooksLoading ||
        isLoadingMore ||
        !hasNext) {
      return;
    }

    // 다음 서버 페이지 20개 조회
    await _fetchTopicsData();

    // 만약 현재 선택된 장르가 여전히 20개 미만이면
    // 20개가 될 때까지 필요한 페이지 추가 조회
    await _ensureMinimumBooks();
  }

  // =========================================================
  // 현재 선택 카테고리 최소 20권 확보
  // =========================================================

  Future<void> _ensureMinimumBooks() async {
    while (mounted &&
        selectBooks.length < minimumVisibleBooks &&
        hasNext) {
      await _fetchTopicsData();

      debugPrint(
        '[$selectedCategory] '
            '${selectBooks.length}/$minimumVisibleBooks권 확보',
      );
    }
  }

  // =========================================================
  // 책 페이지 조회
  // =========================================================

  Future<void> _fetchTopicsData({
    bool reset = false,
  }) async {
    if (isBooksLoading || isLoadingMore) {
      return;
    }

    if (reset) {
      currentPage = 0;
      hasNext = true;

      allBooks.clear();
      books.clear();
      selectBooks.clear();

      if (mounted) {
        setState(() {
          isBooksLoading = true;
        });
      }
    } else {
      if (!hasNext) {
        return;
      }

      if (mounted) {
        setState(() {
          isLoadingMore = true;
        });
      }
    }

    try {
      final int requestPage = currentPage;

      final response = await ApiClient.dio.get(
        '/books',
        queryParameters: {
          'page': requestPage,
          'size': pageSize,
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Books API Error: ${response.statusCode}',
        );
        return;
      }

      final dynamic decoded =
      response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (decoded is! Map) {
        debugPrint(
          'Invalid Books Response: $decoded',
        );
        return;
      }

      final dynamic content = decoded['content'];

      if (content is! List) {
        debugPrint(
          'Books content is not List: $decoded',
        );
        return;
      }

      // =====================================================
      // 현재 페이지 데이터 추가
      // =====================================================

      allBooks.addAll(content);

      // =====================================================
      // 기존 장르 조립 방식 그대로
      // =====================================================

      for (final item in content) {
        if (item is Map) {
          final genre = item['genre'] as String?;

          if (genre != null && genre.isNotEmpty) {
            books
                .putIfAbsent(
              genre,
                  () => [],
            )
                .add(item);
          }
        }
      }

      // =====================================================
      // 서버 페이징 정보
      // =====================================================

      hasNext = decoded['has_next'] == true;

      // 다음에 요청할 페이지
      currentPage = requestPage + 1;

      debugPrint(
        'Books page=$requestPage / '
            'size=$pageSize / '
            'received=${content.length} / '
            'total=${allBooks.length} / '
            'hasNext=$hasNext',
      );

      for (final entry in books.entries) {
        debugPrint(
          '${entry.key}: ${entry.value.length}권',
        );
      }

      if (mounted) {
        setState(() {
          _updateSelectedBooks();
        });
      }
    } catch (e, stackTrace) {
      debugPrint(
        'Books Network/Parsing Error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          isBooksLoading = false;
          isLoadingMore = false;
        });
      }
    }
  }

  // =========================================================
  // 선택 카테고리 화면 데이터 갱신
  // =========================================================

  void _updateSelectedBooks() {
    if (selectedCategory == '전체') {
      selectBooks = List<dynamic>.from(
        allBooks,
      );

      return;
    }

    final genre = categoryMap[selectedCategory];

    if (genre == null) {
      selectBooks = [];
      return;
    }

    selectBooks = List<dynamic>.from(
      books[genre] ?? [],
    );
  }

  // =========================================================
  // 카테고리 선택
  // =========================================================

  Future<void> onCategorySelected(
      String category,
      ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      selectedCategory = category;
      isDropdownOpen = false;

      _updateSelectedBooks();
    });

    // 현재 가지고 있는 책 중 선택 장르가
    // 20권 미만이면 다음 서버 페이지들을 계속 조회
    //
    // 서버 요청 하나당 size=20
    // 선택 장르가 20권 이상 확보되면 중단
    // 서버 마지막 페이지까지 갔다면 있는 만큼 표시
    await _ensureMinimumBooks();
  }

  // =========================================================
  // 배너
  // =========================================================

  Future<void> _buildBannersFromApi() async {
    if (mounted) {
      setState(() => isBannersLoading = true);
    }

    List<dynamic> generatedBanners = [];

    for (int i = 0; i < 6; i++) {
      final meta = _getBannerMeta(i);
      final String theme = meta['theme'];

      List<String> previewImages = [];
      int actualCount = meta['defaultCount'];

      try {
        final response = await ApiClient.dio.get(
          '/books/themes/$theme',
          queryParameters: {
            'limit': 3,
          },
        );

        if (response.statusCode == 200) {
          final decoded =
          response.data is String
              ? jsonDecode(
            response.data as String,
          )
              : response.data;

          List<dynamic> themeBooks =
          decoded is List ? decoded : [];

          actualCount = themeBooks.length;

          for (var b in themeBooks) {
            if (b is Map &&
                b['cover_url'] != null &&
                (b['cover_url'] as String)
                    .isNotEmpty) {
              previewImages.add(
                b['cover_url'] as String,
              );
            }
          }
        }
      } catch (e) {
        debugPrint(
          'Banner fetch error for theme $theme: $e',
        );
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
        isBannersLoading = false;
      });
    }
  }

  Map<String, dynamic> _getBannerMeta(int index) {
    final List<Map<String, dynamic>> metaList = [
      {
        "title":
        "WhoReads의 유명인들이\n가장 많이 추천한 책 TOP20",
        "subtitle":
        "가장 많이 언급된 책은 무엇일까요?",
        "description":
        "WhoReads에 모인 수많은 유명인 추천 중,\n"
            "가장 많이 언급되고 반복해서 추천된 책 TOP 20을 선정했습니다.",
        "defaultCount": 20,
        "theme": "TOP_20",
      },
      {
        "title":
        "각 분야의 유명인들이\n사회를 이해하기 위해 읽은 책",
        "subtitle":
        "세상은 왜 이렇게 돌아갈까요?",
        "description":
        "복잡한 현대 사회와 역사의 흐름을 파악하기 위해\n"
            "각 분야의 전문가와 유명인들이 읽었던 추천 도서입니다.",
        "defaultCount": 20,
        "theme": "SOCIETY",
      },
      {
        "title":
        "각 분야의 유명인들이\n인간을 이해하기 위해 읽은 책",
        "subtitle":
        "인간은 왜 그렇게 행동할까요?",
        "description":
        "심리학과 인문학을 통찰하여\n"
            "사람의 마음과 행동의 본질을 다룬 도서 목록입니다.",
        "defaultCount": 20,
        "theme": "HUMAN_UNDERSTANDING",
      },
      {
        "title":
        "각 분야의 유명인들의\n사고 방식을 바꾼 책",
        "subtitle":
        "생각하는 방식이 달라지는 순간",
        "description":
        "고정관념을 깨고 새로운 관점을 제시해 준\n"
            "명사들의 추천 서적입니다.",
        "defaultCount": 20,
        "theme": "MINDSET",
      },
      {
        "title":
        "각 분야의 유명인들이\n삶의 방향을 고민할 때 읽은 책",
        "subtitle":
        "나는 어떻게 살아야 할까?",
        "description":
        "치열한 고민 끝에 삶의 이정표가 되어 준\n"
            "유명인들의 인생 책 모음입니다.",
        "defaultCount": 20,
        "theme": "LIFE_DIRECTION",
      },
      {
        "title":
        "각 분야의 유명인들이\n인생의 전환점에서 만난 책",
        "subtitle":
        "인생이 바뀌는 순간, 곁에 있던 책",
        "description":
        "커다란 터닝포인트를 맞이했을 때\n"
            "깊은 영감을 선사했던 추천 도서들입니다.",
        "defaultCount": 20,
        "theme": "TURNING_POINT",
      },
    ];

    return metaList[index % metaList.length];
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        title: SvgPicture.asset(
          'assets/images/logo.svg',
          height: 18,
        ),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.black,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const NotificationPage(),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(
              Icons.person_outline,
              color: Colors.black,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const ProfilePage(),
                ),
              );
            },
          ),

          const SizedBox(width: 16),
        ],
      ),

      body: SizedBox(
        height: double.infinity,

        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const SizedBox(height: 16),

                  const Padding(
                    padding:
                    EdgeInsets.symmetric(
                      horizontal: 16,
                    ),

                    child: Text(
                      "이런 주제 어때요?",

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // 배너
                  // =================================================

                  SizedBox(
                    height: 150,

                    child:
                    isBannersLoading &&
                        banners.isEmpty
                        ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(
                            0xFFFF6A00,
                          ),
                        ),
                      ),
                    )
                        : PageView(
                      controller:
                      PageController(
                        viewportFraction:
                        0.7,
                      ),

                      padEnds: false,

                      children: banners.map(
                            (banner) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) =>
                                      TopicBannerPage(
                                        theme:
                                        banner['theme'],
                                        title:
                                        banner['title'],
                                        description:
                                        banner['description'],
                                      ),
                                ),
                              );
                            },

                            child: Padding(
                              padding:
                              const EdgeInsets.only(
                                left: 12,
                              ),

                              child:
                              _TopicBannerCard(
                                banner:
                                banner,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // 카테고리
                  // =================================================

                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),

                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,

                      children: [
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),

                          decoration:
                          BoxDecoration(
                            color:
                            const Color(
                              0xFFFB9566,
                            ),

                            borderRadius:
                            BorderRadius.circular(
                              50,
                            ),
                          ),

                          child: Text(
                            selectedCategory,

                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontWeight:
                              FontWeight
                                  .bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            setState(
                                  () =>
                              isDropdownOpen =
                              !isDropdownOpen,
                            );
                          },

                          child: Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),

                            decoration:
                            BoxDecoration(
                              color:
                              const Color(
                                0xFFF3F4F6,
                              ),

                              borderRadius:
                              BorderRadius.circular(
                                50,
                              ),
                            ),

                            child: Row(
                              children: [
                                Text(
                                  isDropdownOpen
                                      ? '접기'
                                      : '카테고리',

                                  style:
                                  const TextStyle(
                                    fontSize:
                                    13,
                                    color: Colors
                                        .black87,
                                    fontWeight:
                                    FontWeight
                                        .w500,
                                  ),
                                ),

                                const SizedBox(
                                  width: 4,
                                ),

                                Icon(
                                  isDropdownOpen
                                      ? Icons
                                      .keyboard_arrow_up
                                      : Icons
                                      .keyboard_arrow_down,

                                  size: 18,
                                  color:
                                  Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // =================================================
                  // 도서
                  // =================================================

                  if (isBooksLoading &&
                      selectBooks.isEmpty)
                    const SizedBox(
                      height: 200,

                      child: Center(
                        child:
                        CircularProgressIndicator(
                          color: Color(
                            0xFFFF6A00,
                          ),
                        ),
                      ),
                    )
                  else if (selectBooks.isEmpty &&
                      !hasNext)
                    const SizedBox(
                      height: 200,

                      child: Center(
                        child: Text(
                          '표시할 도서 정보가 없습니다.',

                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),

                      child: GridView.builder(
                        physics:
                        const NeverScrollableScrollPhysics(),

                        shrinkWrap: true,

                        addAutomaticKeepAlives:
                        false,

                        addRepaintBoundaries:
                        false,

                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 24,
                          childAspectRatio:
                          0.48,
                        ),

                        itemCount:
                        selectBooks.length,

                        itemBuilder:
                            (context, index) {
                          final dynamic book =
                          selectBooks[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) =>
                                      BookDetailPage(
                                        bookId:
                                        book['id'] ??
                                            book['book_id'],
                                      ),
                                ),
                              );
                            },

                            child:
                            _TopicBookCard(
                              book: book,
                            ),
                          );
                        },
                      ),
                    ),

                  // =================================================
                  // 추가 페이지 로딩
                  // =================================================

                  if (isLoadingMore)
                    const Padding(
                      padding:
                      EdgeInsets.symmetric(
                        vertical: 24,
                      ),

                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,

                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(
                              0xFFFF6A00,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // =====================================================
            // 카테고리 드롭다운
            // =====================================================

            if (isDropdownOpen)
              Positioned.fill(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(
                              () =>
                          isDropdownOpen =
                          false,
                        );
                      },

                      child: Container(
                        color:
                        Colors.transparent,
                      ),
                    ),

                    Positioned(
                      top: 270,
                      left: 0,
                      right: 0,

                      child: Container(
                        margin:
                        const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),

                        constraints:
                        const BoxConstraints(
                          maxHeight: 300,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          Colors.white,

                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withOpacity(
                                0.15,
                              ),

                              blurRadius: 10,

                              offset:
                              const Offset(
                                0,
                                4,
                              ),
                            ),
                          ],
                        ),

                        child:
                        SingleChildScrollView(
                          padding:
                          const EdgeInsets.all(
                            16,
                          ),

                          child:
                          LayoutBuilder(
                            builder:
                                (
                                context,
                                constraints,
                                ) {
                              final itemWidth =
                                  (constraints.maxWidth -
                                      (8 *
                                          3)) /
                                      4;

                              return Wrap(
                                spacing:
                                8,
                                runSpacing:
                                8,

                                children: categoryKeys.map(
                                      (
                                      category,
                                      ) {
                                    final isSelected =
                                        category ==
                                            selectedCategory;

                                    return GestureDetector(
                                      onTap: () {
                                        onCategorySelected(
                                          category,
                                        );
                                      },

                                      child: Container(
                                        width:
                                        itemWidth,

                                        padding:
                                        const EdgeInsets.symmetric(
                                          vertical:
                                          6,
                                        ),

                                        alignment:
                                        Alignment.center,

                                        decoration: BoxDecoration(
                                          color:
                                          Colors.white,

                                          borderRadius:
                                          BorderRadius.circular(
                                            8,
                                          ),

                                          border: Border.all(
                                            color:
                                            isSelected
                                                ? const Color(
                                              0xFFFB9566,
                                            )
                                                : const Color(
                                              0xFFE5E7EB,
                                            ),

                                            width:
                                            1,
                                          ),
                                        ),

                                        child: Text(
                                          category,

                                          style: TextStyle(
                                            fontSize:
                                            12,

                                            color:
                                            isSelected
                                                ? const Color(
                                              0xFFFB9566,
                                            )
                                                : Colors.black87,

                                            fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),

                                          maxLines:
                                          1,

                                          overflow:
                                          TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  },
                                ).toList(),
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
      ),

      // =========================================================
      // Bottom Navigation
      // =========================================================

      bottomNavigationBar:
      BottomNavigationBar(
        currentIndex: 2,

        selectedItemColor:
        const Color(
          0xFFF84E00,
        ),

        unselectedItemColor:
        Colors.grey,

        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,

              MaterialPageRoute(
                builder: (context) =>
                const CelebritiesPage(),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,

              MaterialPageRoute(
                builder: (context) =>
                const MyLibraryPage(),
              ),
            );
          }
        },

        items: const [
          BottomNavigationBarItem(
            icon:
            Icon(Icons.people),
            label: '인물',
          ),

          BottomNavigationBarItem(
            icon:
            Icon(Icons.menu_book),
            label: '내 서재',
          ),

          BottomNavigationBarItem(
            icon:
            Icon(Icons.topic),
            label: '주제',
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 배너 카드
// =============================================================

class _TopicBannerCard extends StatelessWidget {
  final dynamic banner;

  const _TopicBannerCard({
    required this.banner,
  });

  @override
  Widget build(BuildContext context) {
    final String title =
        banner['title'] ?? '';

    final String subtitle =
        banner['subtitle'] ?? '';

    final int count =
        banner['count'] ?? 0;

    final List<dynamic> images =
        banner['images'] ?? [];

    return Container(
      padding:
      const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(12),

        border: Border.all(
          color:
          const Color(
            0xFFFF6A00,
          ),
          width: 1,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.05),

            blurRadius: 4,

            offset:
            const Offset(2, 2),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        mainAxisAlignment:
        MainAxisAlignment
            .spaceBetween,

        children: [
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style:
                const TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.bold,
                  height: 1.3,
                  color:
                  Colors.black87,
                ),

                maxLines: 2,

                overflow:
                TextOverflow.ellipsis,
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                subtitle,

                style:
                const TextStyle(
                  fontSize: 12,
                  color:
                  Colors.grey,
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,

            children: [
              SizedBox(
                width: 80,
                height: 30,

                child: Stack(
                  children:
                  List.generate(
                    images.isNotEmpty
                        ? images
                        .take(3)
                        .length
                        : 3,

                        (index) {
                      final bool
                      hasImage =
                          images.length >
                              index;

                      final String?
                      imgUrl =
                      hasImage
                          ? images[index]
                          : null;

                      return Positioned(
                        left:
                        index *
                            20.0,

                        child: Container(
                          width: 30,
                          height: 30,

                          decoration:
                          BoxDecoration(
                            shape:
                            BoxShape.circle,

                            color: Colors
                                .orange
                                .shade50,

                            border: Border.all(
                              color:
                              Colors.white,
                              width:
                              2,
                            ),
                          ),

                          child: ClipOval(
                            child:
                            imgUrl != null &&
                                imgUrl.isNotEmpty
                                ? Image.network(
                              imgUrl,

                              fit:
                              BoxFit.cover,

                              cacheWidth:
                              60,

                              cacheHeight:
                              60,

                              errorBuilder:
                                  (
                                  _,
                                  __,
                                  ___,
                                  ) => const Icon(
                                Icons.book,
                                size: 16,
                                color: Color(
                                  0xFFFF6A00,
                                ),
                              ),
                            )
                                : const Icon(
                              Icons.book,
                              size: 16,
                              color: Color(
                                0xFFFF6A00,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Text(
                "$count권",

                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  color:
                  Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 책 카드
// =============================================================

class _TopicBookCard extends StatelessWidget {
  final dynamic book;

  const _TopicBookCard({
    required this.book,
  });

  Color _getGenreColor(
      String genre,
      ) {
    if (genre.contains('사회') ||
        genre.contains('역사')) {
      return const Color(
        0xFFF89B05,
      );
    }

    if (genre.contains('자기계발') ||
        genre.contains('심리')) {
      return const Color(
        0xFF0881F9,
      );
    }

    if (genre.contains('문학')) {
      return const Color(
        0xFFF84E00,
      );
    }

    if (genre.contains('과학')) {
      return const Color(
        0xFF1BA430,
      );
    }

    if (genre.contains('경제') ||
        genre.contains('경영')) {
      return const Color(
        0xFF9747FF,
      );
    }

    if (genre.contains('에세이') ||
        genre.contains('회고')) {
      return const Color(
        0xFFFB9566,
      );
    }

    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final String genre =
        book['genre'] ?? '기타';

    final String title =
        book['title'] ?? '';

    final String coverUrl =
        book['cover_url'] ?? '';

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.center,

      children: [
        Expanded(
          child: Container(
            width: double.infinity,

            decoration:
            BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors
                      .black
                      .withOpacity(
                    0.1,
                  ),

                  blurRadius: 5,

                  offset:
                  const Offset(
                    2,
                    4,
                  ),
                ),
              ],
            ),

            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(
                4,
              ),

              child:
              coverUrl.isNotEmpty
                  ? Image.network(
                coverUrl,

                fit:
                BoxFit.cover,

                cacheWidth: 300,
                cacheHeight: 450,

                errorBuilder:
                    (
                    context,
                    error,
                    stackTrace,
                    ) => Container(
                  color:
                  Colors.grey[200],

                  child:
                  const Center(
                    child:
                    Icon(
                      Icons.book,
                      color:
                      Colors.grey,
                    ),
                  ),
                ),
              )
                  : Container(
                color:
                Colors.grey[200],

                child:
                const Center(
                  child:
                  Icon(
                    Icons.book,
                    color:
                    Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          title,

          maxLines: 1,

          overflow:
          TextOverflow.ellipsis,

          textAlign:
          TextAlign.center,

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
            fontSize: 13,
            color:
            Colors.black87,
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Align(
          alignment:
          Alignment.topCenter,

          child: Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),

            decoration:
            BoxDecoration(
              color:
              _getGenreColor(
                genre,
              ),

              borderRadius:
              BorderRadius.circular(
                8,
              ),
            ),

            child: FittedBox(
              fit:
              BoxFit.scaleDown,

              child: Text(
                genre,

                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}