import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:whoreads/screens/notification_screen.dart';
import 'package:whoreads/screens/topics/topics_page.dart';
import '../../core/network/api_client.dart';
import '../../widgets/common/job_tag.dart';
import '../my_library/my_library_page.dart';
import '../users/profile.dart';
import 'celebrities_book_page.dart';

class CelebritiesPage extends StatefulWidget {
  const CelebritiesPage({super.key});

  @override
  State<CelebritiesPage> createState() => _CelebritiesPageState();
}

class _CelebritiesPageState extends State<CelebritiesPage> {
  final ScrollController _scrollController = ScrollController();

  String selectedCategory = '전체';
  bool isDropdownOpen = false;

  List<dynamic> celebrities = [];
  bool isLoading = false;
  int _requestId = 0;

  Map<String, String?> categoryMap = {
    '전체': null,
    '학자': 'SCHOLAR',
    '스포츠선수': 'ATHLETE',
    '과학관장': 'PHYSICIST',
    '가수': 'SINGER',
    '아나운서': 'ANNOUNCER',
    '개그맨': 'COMEDIAN',
    '영화감독': 'MOVIE_DIRECTOR',
    '번역가': 'TRANSLATOR',
    '프로파일러': 'PROFILER',
    '정치인': 'POLITICIAN',
    '강사': 'INSTRUCTOR',
    '배우': 'ACTOR',
    '뮤지컬배우': 'MUSICAL_ACTOR',
    '작사가': 'LYRICIST',
    '생물학자': 'BIOLOGIST',
    '교수': 'PROFESSOR',
    '기업가': 'ENTREPRENEUR',
    '유튜버': 'YOUTUBER',
    '요리사': 'CHEF',
    '언론비평가': 'MEDIA_CRITIC',
    '작가': 'WRITER',
    '아이돌': 'IDOL',
  };

  List<String> get categoryKeys => categoryMap.keys.toList();

  @override
  void initState() {
    super.initState();
    fetchCelebritiesCategories();
    fetchCelebrities();
  }

  Future<void> fetchCelebritiesCategories() async {
    if (!mounted) return;

    try {
      final response = await ApiClient.dio.get('/celebrities/categories');

      debugPrint('STATUS CODE: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final List<dynamic> items;
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded['result'] is List) {
          items = decoded['result'] as List<dynamic>;
        } else {
          items = [];
        }

        final Map<String, String?> newCategoryMap = {'전체': null};

        for (var it in items) {
          if (it['name'] == '전체') continue;
          newCategoryMap.putIfAbsent(it['name'], () => it['code']);
        }

        if (!mounted) return;

        setState(() {
          categoryMap = newCategoryMap;
        });
      } else {
        debugPrint('API 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('네트워크 에러: $e');
    }
  }

  Future<void> fetchCelebrities() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    final requestId = ++_requestId;
    final tag = categoryMap[selectedCategory];

    try {
      final response = await ApiClient.dio.get(
        '/celebrities',
        queryParameters: tag == null ? null : {'tag': tag},
      );

      debugPrint('STATUS CODE: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final List<dynamic> items;
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded['result'] is List) {
          items = decoded['result'] as List<dynamic>;
        } else {
          items = [];
        }

        if (!mounted || requestId != _requestId) return;

        setState(() {
          celebrities = items;
        });
      } else {
        debugPrint('API 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('네트워크 에러: $e');
    }

    if (!mounted || requestId != _requestId) return;

    setState(() => isLoading = false);
  }

  void onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      isDropdownOpen = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    fetchCelebrities();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          Column(
            children: [
              /// ===== 상단 카테고리 바 =====
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isDropdownOpen ? '접기' : '카테고리',
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

              /// ===== 인물 리스트 =====
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : celebrities.isEmpty
                    ? const Center(child: Text('표시할 인물 정보가 없습니다.'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = (constraints.maxWidth - 56) / 3;
                          final scaler = MediaQuery.textScalerOf(context);
                          var tagHeight = scaler.scale(12) * 1.3;
                          for (final celeb in celebrities) {
                            for (final tag
                                in (celeb['job_tags'] as List? ?? []).take(2)) {
                              final painter = TextPainter(
                                text: TextSpan(
                                  text: tag.toString(),
                                  style: JobTag.textStyle,
                                ),
                                textScaler: scaler,
                                textDirection: Directionality.of(context),
                                maxLines: 2,
                              )..layout(maxWidth: cardWidth - 16);
                              if (painter.height > tagHeight) {
                                tagHeight = painter.height;
                              }
                              painter.dispose();
                            }
                          }
                          final cardHeight =
                              cardWidth * 4 / 3 +
                              6 +
                              scaler.scale(14) * 1.3 +
                              4 +
                              2 * (tagHeight + 8) +
                              4;
                          return GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 24,
                                  mainAxisExtent: cardHeight.ceilToDouble() + 1,
                                ),
                            itemCount: celebrities.length,
                            itemBuilder: (context, index) {
                              return _CelebrityCard(celeb: celebrities[index]);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),

          /// ===== [드롭다운 오버레이] =====
          if (isDropdownOpen)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Container(
                key: const ValueKey('celebrities-category-menu'),
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
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
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
              MaterialPageRoute(builder: (context) => const MyLibraryPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TopicsPage()),
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

/// ================= 인물 카드 =================
class _CelebrityCard extends StatelessWidget {
  final dynamic celeb;

  const _CelebrityCard({required this.celeb});

  @override
  Widget build(BuildContext context) {
    final List tags = celeb['job_tags'] ?? [];

    return GestureDetector(
      onTap: () {
        debugPrint('인물 클릭: ${celeb['name']} (ID: ${celeb['id']})');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CelebritiesBookPage(celebrityId: celeb['id']),
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
                celeb['image_url']?.toString() ?? '',
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
            celeb['name']?.toString() ?? '이름 없음',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: tags
                .take(2)
                .map<Widget>((tag) => JobTag(tag.toString()))
                .toList(),
          ),
        ],
      ),
    );
  }
}
