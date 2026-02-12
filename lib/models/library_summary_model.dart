class LibrarySummaryModel {
  final int completedCount;
  final int readingCount;
  final int totalReadMinutes;

  LibrarySummaryModel({
    required this.completedCount,
    required this.readingCount,
    required this.totalReadMinutes,
  });

  factory LibrarySummaryModel.fromJson(Map<String, dynamic> json) {
    return LibrarySummaryModel(
      completedCount: json['completed_count'] ?? 0,
      readingCount: json['reading_count'] ?? 0,
      totalReadMinutes: json['total_read_minutes'] ?? 0,
    );
  }
}
