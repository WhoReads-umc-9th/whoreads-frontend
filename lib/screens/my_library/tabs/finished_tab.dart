import 'package:flutter/material.dart';
import '../../../models/book_model.dart';
import '../widgets/book_list_item.dart';

class FinishedTab extends StatelessWidget {
  final List<BookModel> books;

  const FinishedTab({
    super.key,
    required this.books,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const Center(
        child: Text(
          '아직 다 읽은 책이 없습니다.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
        return BookListItem(
          book: books[index],
          showProgress: false, // 다 읽음이니까 진행률 필요 없음
        );
      },
    );
  }
}
