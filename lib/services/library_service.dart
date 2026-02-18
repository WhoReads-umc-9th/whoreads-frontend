import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/library_book_model.dart';

class LibraryService {
  static const String _baseUrl = 'http://43.201.122.162';

  static Future<List<LibraryBookModel>> fetchBooks({
    required String status, // WISH / READING / COMPLETE
    required String accessToken,
    int size = 10,
  }) async {
    final uri = Uri.parse(
        '$_baseUrl/api/me/library/list?status=$status&size=$size');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded['is_success'] == true) {
        final List books = decoded['result']['books'];

        return books
            .map((e) => LibraryBookModel.fromJson(e))
            .toList();
      }
    }

    return [];
  }
}