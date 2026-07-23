import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../books/BookDetailPage.dart';

class TopicBannerPage extends StatefulWidget {
  final String? theme;
  final String title;
  final String? description;
  final List<dynamic>? initialBooks;

  const TopicBannerPage({
    super.key,
    this.theme,
    required this.title,
    this.description,
    this.initialBooks,
  });

  @override
  State<TopicBannerPage> createState() => _TopicBannerPageState();
}

class _TopicBannerPageState extends State<TopicBannerPage> {
  bool isLoading = false;
  List<dynamic> books = [];

  @override
  void initState() {
    super.initState();
    _fetchTopicBooks();
  }

  Future<void> _fetchTopicBooks() async {
    if (widget.theme == null || widget.theme!.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final response = await ApiClient.dio.get(
        '/books/themes/${widget.theme}',
        queryParameters: {'limit': 20},
      );

      if (response.statusCode == 200) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;

        setState(() {
          if (decoded is List) {
            books = decoded;
          } else if (decoded is Map && decoded['result'] is List) {
            books = decoded['result'];
          } else if (decoded is Map && decoded['books'] is List) {
            books = decoded['books'];
          } else {
            books = [];
          }
        });
      }
    } catch (e) {
      debugPrint('주제 상세 도서 조회 오류: $e');
    } finally {
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

            Text(
              widget.title.replaceAll('\n', ' '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.description ?? "WhoReads의 유명인들이 추천하고\n깊이 있게 읽은 대표 도서 목록입니다.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),

            const Divider(thickness: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),

            Expanded(
              child: books.isEmpty
                  ? const Center(
                child: Text(
                  '등록된 도서가 없습니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              )
                  : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.55,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final genre = book['genre'] ?? '기타';
                  final title = book['title'] ?? '제목 없음';
                  final coverUrl = book['cover_url'] ?? '';

                  return GestureDetector(
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