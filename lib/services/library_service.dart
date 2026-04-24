import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/library_book_model.dart';
import '../core/network/api_client.dart';

class LibraryService {
  static Future<List<LibraryBookModel>> fetchBooks({
    required String status, // WISH / READING / COMPLETE
    int size = 10,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        '/me/library/list',
        queryParameters: {
          'status': status,
          'size': size,
        },
      );

      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (response.statusCode == 200 && decoded['is_success'] == true) {
        final List books = decoded['result']['books'];
        return books.map((e) => LibraryBookModel.fromJson(e)).toList();
      }
    } on DioException catch (e) {
      // 네트워크/SSL/401 등 예외가 있어도 리스트 탭이 죽지 않도록 빈 배열 반환
      // ignore: avoid_print
      print('LibraryService.fetchBooks failed: ${e.message}');
    } catch (_) {
      // 실패 시 빈 배열
    }

    return [];
  }
}