class LibraryBookModel {
  final int id;
  final String title;
  final String author;
  final String? coverUrl;
  final int totalPages;
  final int currentPage;

  LibraryBookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.totalPages,
    required this.currentPage,
  });

  double get progress =>
      totalPages == 0 ? 0 : currentPage / totalPages;

  factory LibraryBookModel.fromJson(Map<String, dynamic> json) {
    final book = json['book'];

    return LibraryBookModel(
      id: book['id'],
      title: book['title'],
      author: book['author_name'],
      coverUrl: book['cover_url'],
      totalPages: book['total_page'] ?? 0,
      currentPage: json['reading_page'] ?? 0,
    );
  }
}
