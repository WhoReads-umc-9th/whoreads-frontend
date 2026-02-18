import 'package:flutter/material.dart';
import 'package:whoreads/screens/my_library/widgets/book_list_item.dart';
import '../../../models/library_book_model.dart';
import '../../../services/library_service.dart';
import '../../books/BookDetailPage.dart';

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
      return const Center(child: Text("담아둔 책이 없습니다."));
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (_, index) {
        final book = books[index];

        return BookListItem(
          book: book,
          showProgress: false,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailPage(
                  bookId: book.id,   // 🔥 여기 네 모델 필드명 확인
                ),
              ),
            );
          },
        );
      },
    );

  }
}
