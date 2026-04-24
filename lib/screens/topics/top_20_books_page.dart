import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
// 🌟 1. 상세 페이지 import 주석 해제
import '../books/BookDetailPage.dart';

class Top20BooksPage extends StatefulWidget {
  const Top20BooksPage({super.key});

  @override
  State<Top20BooksPage> createState() => _Top20BooksPageState();
}

class _Top20BooksPageState extends State<Top20BooksPage> {
  bool isLoading = true;
  List<dynamic> topBooks = [];

  @override
  void initState() {
    super.initState();
    _fetchTop20Books();
  }

  Future<void> _fetchTop20Books() async {
    try {
      final response = await ApiClient.dio.get(
        '/books/ranks',
        queryParameters: {'limit': 20},
      );

      if (response.statusCode == 200) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;

        final prettyString = const JsonEncoder.withIndent('  ').convert(decoded);
        debugPrint('📦 [TOP 20 API 응답]:\n$prettyString');

        setState(() {
          if (decoded is List) {
            topBooks = decoded;
          } else if (decoded is Map && decoded['result'] is List) {
            topBooks = decoded['result'];
          } else {
            topBooks = [];
          }
          isLoading = false;
        });
      } else {
        debugPrint('API 에러: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('네트워크 에러: $e');
      setState(() => isLoading = false);
    }
  }

  Color _getGenreColor(String genre) {
    if (genre.contains('사회') || genre.contains('역사')) return const Color(0xFFF89B05);
    if (genre.contains('자기계발') || genre.contains('심리')) return const Color(0xFF0881F9);
    if (genre.contains('문학')) return const Color(0xFFF84E00);
    if (genre.contains('과학') || genre.contains('기술')) return const Color(0xFF1BA430);
    if (genre.contains('인문') || genre.contains('철학')) return const Color(0xFF9747FF);
    if (genre.contains('에세이') || genre.contains('회고')) return const Color(0xFFFB9566);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00)))
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // 1. 헤더 타이틀 및 설명
            const Text(
              "WhoReads의 유명인들이\n가장 많이 추천한 책 TOP 20",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "WhoReads에 모인 수많은 유명인 추천 중,\n가장 많이 언급되고 반복해서 추천된 책 TOP 20을 선정했습니다.\n지금 바로 유명인들의 인기 추천 도서를 확인해 보세요.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 가로 구분선
            const Divider(thickness: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),

            // 3. 책 3열 그리드
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.55,
                ),
                itemCount: topBooks.length,
                itemBuilder: (context, index) {
                  final book = topBooks[index];
                  final genre = book['genre'] ?? '기타';
                  final title = book['title'] ?? '제목 없음';
                  final coverUrl = book['cover_url'] ?? '';

                  return GestureDetector(
                    // 🌟 2. 클릭 이벤트 활성화 (상세 페이지로 이동)
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailPage(
                            bookId: book['id'] ?? book['book_id'],
                          ),
                        ),
                      );
                    },
                    child: Column(
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
                                errorBuilder: (_, __, ___) => Container(
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
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getGenreColor(genre),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            genre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}