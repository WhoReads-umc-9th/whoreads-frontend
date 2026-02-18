import 'package:flutter/material.dart';
import '../../../models/library_book_model.dart';
import '../../../services/library_service.dart';
import '../widgets/book_list_item.dart';

class FinishedTab extends StatefulWidget {
  final String accessToken;

  const FinishedTab({super.key, required this.accessToken, required List<dynamic> books});

  @override
  State<FinishedTab> createState() => _FinishedTabState();
}

class _FinishedTabState extends State<FinishedTab> {
  List<LibraryBookModel> books = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await LibraryService.fetchBooks(
      status: "COMPLETE",
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
      return const Center(child: Text("다 읽은 책이 없습니다."));
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (_, index) {
        return BookListItem(
          book: books[index],
          showProgress: false,
        );
      },
    );
  }
}
