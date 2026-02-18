class CelebrityModel {
  final int id;
  final String profileUrl;

  CelebrityModel({
    required this.id,
    required this.profileUrl,
  });

  factory CelebrityModel.fromJson(Map<String, dynamic> json) {
    return CelebrityModel(
      id: json['id'] ?? 0,
      profileUrl: json['profile_url'] ?? '',
    );
  }
}

class LibraryBookModel {
  final int id;
  final String title;
  final String author;
  final String? coverUrl;
  final int totalPages;
  final int currentPage;
  final int celebritiesCount;
  final List<CelebrityModel> celebrities;

  LibraryBookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.totalPages,
    required this.currentPage, required this.celebritiesCount, required this.celebrities,
  });

  double get progress =>
      totalPages == 0 ? 0 : currentPage / totalPages;

  factory LibraryBookModel.fromJson(Map<String, dynamic> json) {
    final bookJson = json['book'] ?? {};
    // celebrities 배열 파싱
    var celebritiesList = json['celebrities'] as List? ?? [];
    List<CelebrityModel> celebrities = celebritiesList
        .map((e) => CelebrityModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return LibraryBookModel(
      id: bookJson['id'] ?? 0,
      title: bookJson['title'] ?? '',
      author: bookJson['author_name'] ?? '',
      coverUrl: bookJson['cover_url'],
      totalPages: bookJson['total_page'] ?? 0,
      currentPage: json['reading_page'] ?? 0,
      celebritiesCount: json['celebrities_count'] ?? 0,
      celebrities: celebrities,
    );
  }
}
