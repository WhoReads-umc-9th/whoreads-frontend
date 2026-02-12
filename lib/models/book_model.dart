class BookModel {
  final int id;
  final String title;
  final String author;
  final String? coverUrl;
  final int totalPages;
  final int currentPage;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.totalPages,
    required this.currentPage,
  });

  double get progress =>
      totalPages == 0 ? 0 : currentPage / totalPages;

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      coverUrl: json['cover_url'],
      totalPages: json['total_pages'] ?? 0,
      currentPage: json['current_page'] ?? 0,
    );
  }
}
