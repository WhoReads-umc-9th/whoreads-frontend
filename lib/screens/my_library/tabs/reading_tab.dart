import 'package:flutter/material.dart';
import '../../../models/book_model.dart';
import '../widgets/book_list_item.dart';

class ReadingTab extends StatelessWidget {
  final List<BookModel> books;

  const ReadingTab({
    super.key,
    required this.books,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const Center(
        child: Text(
          '현재 읽고 있는 책이 없습니다.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
        return BookListItem(
          book: books[index],
          showProgress: true,
        );
      },
    );
  }
}
