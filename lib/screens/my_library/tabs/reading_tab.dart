import 'package:flutter/material.dart';
import '../../../models/library_book_model.dart';
import '../../../services/library_service.dart';
import '../../books/BookDetailPage.dart';
import '../widgets/book_list_item.dart';

class ReadingTab extends StatefulWidget {
  const ReadingTab({super.key, required List<dynamic> books});

  @override
  State<ReadingTab> createState() => _ReadingTabState();
}

class _ReadingTabState extends State<ReadingTab> {
  List<LibraryBookModel> books = [];
  bool isLoading = true;
  String? _error;
  Object? _cursor;
  bool _retryAppend = false;
  bool _hasMore = false;
  bool _requestInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    _retryAppend = append;
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final result = await LibraryService.fetchPage(
        status: 'READING',
        size: 20,
        cursor: append ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        books = append
            ? [
                ...books,
                ...result.books.where(
                  (book) => !books.any((old) => old.id == book.id),
                ),
              ]
            : result.books;
        _cursor = result.nextCursor;
        _hasMore = result.hasNext;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '서재를 불러오지 못했습니다. 다시 시도해주세요.');
    } finally {
      _requestInFlight = false;
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _load(append: _retryAppend),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (books.isEmpty) {
      return const Center(child: Text("읽는 중인 책이 없습니다."));
    }

    return ListView.builder(
      itemCount: books.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == books.length) {
          return TextButton(
            onPressed: () {
              _load(append: true);
            },
            child: const Text('더 보기'),
          );
        }
        final book = books[index]; // 현재 책 변수 할당

        return BookListItem(
          book: book,
          showProgress: true,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailPage(bookId: book.id),
              ),
            );
            _load();
          },
        );
      },
    );
  }
}
