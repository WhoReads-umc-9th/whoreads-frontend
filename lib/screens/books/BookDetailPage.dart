import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../widgets/book/QuoteCard.dart';

class BookDetailPage extends StatefulWidget {
  final int bookId;

  const BookDetailPage({
    super.key,
    required this.bookId,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  bool isLoading = true;

  String? title;
  String? authorName;
  String? coverUrl;
  int? totalPage;

  String selectedStatus = "WISH"; // WISH / READING / DONE

  @override
  void initState() {
    super.initState();
    _fetchBookDetail();
  }

  Future<void> _fetchBookDetail() async {
    final response = await http.get(
      Uri.parse('http://43.201.122.162/api/books/${widget.bookId}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        title = data['title'];
        authorName = data['author_name'];
        coverUrl = data['cover_url'];
        totalPage = data['total_page'];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Widget _buildStatusButton(String label, String value) {
    final isSelected = selectedStatus == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8A5B) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.more_horiz, color: Colors.black),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 16),

            /// 📕 상단 책 정보
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  coverUrl ?? '',
                  width: 110,
                  height: 160,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        authorName ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 12),

                      /// 📌 상태 버튼들
                      Row(
                        children: [
                          _buildStatusButton("담아둠", "WISH"),
                          const SizedBox(width: 8),
                          _buildStatusButton("읽는 중", "READING"),
                          const SizedBox(width: 8),
                          _buildStatusButton("다 읽음", "DONE"),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// 📌 태그
                      _buildTag("문학"),

                      const SizedBox(height: 12),

                      /// 📌 책 더 자세히 보기
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          "책 더 자세히 보기",
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 24),

            /// 🔹 안내 박스
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  "이 책을 읽으면 아래 유명인들과 더 친밀해질 수 있어요!",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// 🔹 가로선
            const Divider(
              thickness: 1,
              height: 1,
              color: Colors.grey,
            ),

            const SizedBox(height: 24),

            /// 📌 인용구 카드
            const QuoteCard(
              profileImage:
              'https://i.pravatar.cc/150?img=47',
              name: '이지영',
              job: '가수',
              quote:
              '이 책은 인간의 본질을 다시 생각하게 만드는 작품입니다. 사회 구조에 대한 통찰이 인상 깊었습니다.',
              source: '추천사 출처',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
