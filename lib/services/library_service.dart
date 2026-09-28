import 'dart:convert';
import 'package:dio/dio.dart';
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

class LibraryService {
  /// 담아둠/읽는 중/다 읽음 탭 목록에서 해당 카탈로그 책이 있는지 검색합니다.
  static Future<CatalogBookLibrarySnapshot?> lookupCatalogBookInLibrary(
    int catalogBookId, {
    int size = 200,
  }) async {
    const statuses = ['WISH', 'READING', 'COMPLETE'];
    for (final status in statuses) {
      try {
        final response = await ApiClient.dio.get(
          '/me/library/list',
          queryParameters: {'status': status, 'size': size},
        );
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        if (response.statusCode != 200 || decoded is! Map) {
          continue;
        }
        if (decoded['is_success'] == false) {
          continue;
        }
        final resultData = decoded['result'];
        List<dynamic> items = [];
        if (resultData is List) {
          items = resultData;
        } else if (resultData is Map) {
          if (resultData['books'] != null) {
            items = List<dynamic>.from(resultData['books'] as List);
          } else if (resultData['content'] != null) {
            items = List<dynamic>.from(resultData['content'] as List);
          }
        }
        for (final raw in items) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final bookNode = item['book'];
          int? bid;
          if (bookNode is Map) {
            bid = int.tryParse('${bookNode['id']}');
          }
          bid ??= int.tryParse('${item['book_id']}');
          if (bid != catalogBookId) continue;

          final int? ubid =
              int.tryParse('${item['user_book_id']}') ??
              int.tryParse('${item['id']}');
          if (ubid == null) continue;

          final String rs =
              (item['reading_status'] ?? status)?.toString() ?? status;

          final int? readingPage = int.tryParse('${item['reading_page']}');
          int? totalPage;
          if (bookNode is Map) {
            totalPage = int.tryParse('${bookNode['total_page']}');
          }
          return CatalogBookLibrarySnapshot(
            userBookId: ubid,
            readingStatus: rs,
            readingPage: readingPage,
            totalPage: totalPage,
            startedAt: item['started_at']?.toString(),
            completedAt: item['completed_at']?.toString(),
          );
        }
      } on DioException catch (_) {
        continue;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<Map<int, int>> fetchAddedBookIdsByUserBookIds({
    int sizePerStatus = 200,
  }) async {
    final map = <int, int>{};
    const statuses = ['WISH', 'READING', 'COMPLETE'];
    await Future.wait(
      statuses.map((status) async {
        try {
          final response = await ApiClient.dio.get(
            '/me/library/list',
            queryParameters: {'status': status, 'size': sizePerStatus},
          );
          final decoded = response.data is String
              ? jsonDecode(response.data as String)
              : response.data;
          if (response.statusCode != 200 || decoded is! Map) {
            return;
          }
          if (decoded['is_success'] == false) {
            return;
          }
          final resultData = decoded['result'];
          List<dynamic> items = [];
          if (resultData is List) {
            items = resultData;
          } else if (resultData is Map) {
            if (resultData['books'] != null) {
              items = List<dynamic>.from(resultData['books'] as List);
            } else if (resultData['content'] != null) {
              items = List<dynamic>.from(resultData['content'] as List);
            }
          }
          for (final raw in items) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final bookNode = item['book'];
            int? bid;
            if (bookNode is Map) {
              bid = int.tryParse('${bookNode['id']}');
            }
            bid ??= int.tryParse('${item['book_id']}');
            final int? ubid =
                int.tryParse('${item['user_book_id']}') ??
                int.tryParse('${item['id']}');
            if (bid != null && ubid != null) {
              map[bid] = ubid;
            }
          }
        } catch (_) {
          // skip
        }
      }),
    );
    return map;
  }

  static Future<List<LibraryBookModel>> fetchBooks({
    required String status,
    int size = 20,
  }) async {
    final response = await ApiClient.checked(
      ApiClient.dio.get(
        '/me/library/list',
        queryParameters: {'status': status, 'size': size},
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
    final books = decoded['result']['books'] as List;
    return books.map((e) => LibraryBookModel.fromJson(e)).toList();
  }
}
