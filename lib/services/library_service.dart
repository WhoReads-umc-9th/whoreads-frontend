import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/library_summary_model.dart';

class LibraryService {
  static const String _baseUrl = 'http://43.201.122.162';

  static Future<LibrarySummaryModel?> fetchSummary(String accessToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/me/library/summary'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded['is_success'] == true) {
        return LibrarySummaryModel.fromJson(decoded['result']);
      }
    }

    return null;
  }
}
