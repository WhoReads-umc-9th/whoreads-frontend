import 'dart:convert';
import '../models/library_book_model.dart';
import '../core/network/api_client.dart';

/// 서재에 담긴 한 권을 카탈로그 `book.id` 기준으로 찾았을 때의 스냅샷 (상세 API `reading_info` 보완용)
class CatalogBookLibrarySnapshot {
  final int userBookId;
  final String readingStatus;
  final int? readingPage;
  final int? totalPage;
  final String? startedAt;
  final String? completedAt;

  const CatalogBookLibrarySnapshot({
    required this.userBookId,
    required this.readingStatus,
    this.readingPage,
    this.totalPage,
    this.startedAt,
    this.completedAt,
  });
}

class LibraryPageResult {
  const LibraryPageResult(this.books, this.hasNext, this.nextCursor);
  final List<LibraryBookModel> books;
  final bool hasNext;
  final Object? nextCursor;
}

class LibraryService {
  static int? _int(dynamic value) => int.tryParse('$value');

  static Stream<Map<String, dynamic>> _rows(String status, int size) async* {
    Object? cursor;
    final seen = <Object>{};
    while (true) {
      final response = await ApiClient.checked(
        ApiClient.dio.get(
          '/me/library/list',
          queryParameters: {
            'status': status,
            'size': size,
            if (cursor != null) 'cursor': cursor,
          },
        ),
      );
      final decoded = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      if (decoded is! Map || decoded['is_success'] == false) {
        throw const FormatException('Invalid library response');
      }
      final result = decoded['result'];
      final items = result is List
          ? result
          : result?['books'] ?? result?['content'];
      if (items is! List) throw const FormatException('Invalid library books');
      for (final item in items) {
        if (item is Map) yield Map<String, dynamic>.from(item);
      }
      if (result is! Map || result['has_next'] != true) return;
      final next = result['next_cursor'];
      if (next == null || items.isEmpty || !seen.add(next)) {
        throw const FormatException('Invalid library pagination cursor');
      }
      cursor = next;
    }
  }

  static Future<CatalogBookLibrarySnapshot?> lookupCatalogBookInLibrary(
    int catalogBookId, {
    int size = 200,
  }) async {
    for (final status in ['WISH', 'READING', 'COMPLETE']) {
      await for (final item in _rows(status, size)) {
        final book = item['book'] is Map ? item['book'] as Map : const {};
        if ((_int(book['id']) ?? _int(item['book_id'])) != catalogBookId)
          continue;
        final id = _int(item['user_book_id']) ?? _int(item['id']);
        if (id == null) continue;
        return CatalogBookLibrarySnapshot(
          userBookId: id,
          readingStatus: (item['reading_status'] ?? status).toString(),
          readingPage: _int(item['reading_page']),
          totalPage: _int(book['total_page']),
          startedAt: item['started_at']?.toString(),
          completedAt: item['completed_at']?.toString(),
        );
      }
    }
    return null;
  }

  static Future<Map<int, int>> fetchAddedBookIdsByUserBookIds({
    int sizePerStatus = 200,
  }) async {
    final result = <int, int>{};
    for (final status in ['WISH', 'READING', 'COMPLETE']) {
      await for (final item in _rows(status, sizePerStatus)) {
        final book = item['book'] is Map ? item['book'] as Map : const {};
        final bookId = _int(book['id']) ?? _int(item['book_id']);
        final userBookId = _int(item['user_book_id']) ?? _int(item['id']);
        if (bookId != null && userBookId != null) result[bookId] = userBookId;
      }
    }
    return result;
  }

  static Future<LibraryPageResult> fetchPage({
    required String status,
    int size = 20,
    Object? cursor,
  }) async {
    final response = await ApiClient.checked(
      ApiClient.dio.get(
        '/me/library/list',
        queryParameters: {
          'status': status,
          'size': size,
          if (cursor != null) 'cursor': cursor,
        },
      ),
    );
    final decoded = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (decoded is! Map ||
        decoded['is_success'] != true ||
        decoded['result'] is! Map ||
        decoded['result']['books'] is! List) {
      throw const FormatException('Invalid library response');
    }
    final result = decoded['result'] as Map;
    final items = (result['books'] as List)
        .map((e) => LibraryBookModel.fromJson(e))
        .toList();
    final next = result['next_cursor'];
    if (result['has_next'] == true &&
        (next == null || next == cursor || items.isEmpty)) {
      throw const FormatException('Invalid library pagination cursor');
    }
    return LibraryPageResult(items, result['has_next'] == true, next);
  }

  static Future<List<LibraryBookModel>> fetchBooks({
    required String status,
    int size = 20,
  }) async {
    return (await fetchPage(status: status, size: size)).books;
  }
}
