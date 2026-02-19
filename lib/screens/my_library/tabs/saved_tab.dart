import 'package:flutter/material.dart';
import 'package:whoreads/screens/my_library/widgets/book_list_item.dart';
import '../../../models/library_book_model.dart';
import '../../../services/library_service.dart';
import '../../books/BookDetailPage.dart';
import '../../celebrities/celebrities_page.dart';

class SavedTab extends StatefulWidget {
  final String accessToken;

  const SavedTab({super.key, required this.accessToken});

  @override
  State<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<SavedTab> {
  List<LibraryBookModel> books = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await LibraryService.fetchBooks(
      status: "WISH",
      accessToken: widget.accessToken,
    );

    setState(() {
      books = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 세로 중앙 정렬
          children: [
            const Text(
              "아직 담아둔 책이 없어요",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4B5563), // 진한 회색
              ),
            ),
            const SizedBox(height: 8), // 텍스트 사이 간격
            const Text(
              "유명인들의 추천 책을 보러갈까요?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280), // 연한 회색
              ),
            ),
            const SizedBox(height: 24), // 텍스트와 버튼 사이 간격

            // [추천 책 보러 가기 버튼]
            ElevatedButton(
              onPressed: () {
                // 버튼 클릭 시 '인물(CelebritiesPage)' 페이지로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CelebritiesPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE88A60), // 사진 속 주황색 (테라코타)
                foregroundColor: Colors.white, // 글자색 흰색
                elevation: 0, // 그림자 없애기 (사진처럼 플랫하게)
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // 둥근 모서리
                ),
              ),
              child: const Text(
                "추천 책 보러 가기",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (_, index) {
        final book = books[index];

        return BookListItem(
          book: book,
          showProgress: false,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailPage(
                  bookId: book.id,
                ),
              ),
            );
            _load();
          },
        );
      },
    );

  }
}
