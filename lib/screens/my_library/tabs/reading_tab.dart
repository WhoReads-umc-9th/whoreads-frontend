import 'package:flutter/material.dart';
import '../../../models/library_book_model.dart';
import '../../../services/library_service.dart';
import '../../books/BookDetailPage.dart';
import '../widgets/book_list_item.dart';

class ReadingTab extends StatefulWidget {
  final String accessToken;

  const ReadingTab({super.key, required this.accessToken, required List<dynamic> books});

  @override
  State<ReadingTab> createState() => _ReadingTabState();
}

class _ReadingTabState extends State<ReadingTab> {
  List<LibraryBookModel> books = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await LibraryService.fetchBooks(
      status: "READING",
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
      return const Center(child: Text("읽는 중인 책이 없습니다."));
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (_, index) {
        final book = books[index]; // 현재 책 변수 할당

        return BookListItem(
          book: book,
          showProgress: true,
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

