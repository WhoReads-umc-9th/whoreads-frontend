class DnaQuestion {
  final int id;
  final int? step; // [수정] int -> int? (null 허용)
  final String content;
  final List<DnaOption> options;

  DnaQuestion({
    required this.id,
    this.step, // required 제거
    required this.content,
    required this.options,
  });

  factory DnaQuestion.fromJson(Map<String, dynamic> json) {
    return DnaQuestion(
      id: json['id'] ?? 0,
      step: json['step'], // [수정] ?? 0 제거 (없으면 null)
      content: json['content'] ?? '',
      options: (json['options'] as List? ?? [])
          .map((e) => DnaOption.fromJson(e))
          .toList(),
    );
  }
}

// ... DnaOption, DnaResult는 기존과 동일
class DnaOption {
  final int id;
  final String content;
  final String? code;
  final int? score;

  DnaOption({
    required this.id,
    required this.content,
    this.code,
    this.score,
  });

  factory DnaOption.fromJson(Map<String, dynamic> json) {
    return DnaOption(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      code: json['track_code'],
      score: json['score'],
    );
  }
}

class DnaResult {
  final String headline;
  final List<String> description;
  final String celebrityName;
  final String imageUrl;
  final List<String> jobTags;

  DnaResult({
    required this.headline,
    required this.description,
    required this.celebrityName,
    required this.imageUrl,
    required this.jobTags,
  });

  factory DnaResult.fromJson(Map<String, dynamic> json) {
    return DnaResult(
      headline: json['result_hea_line'] ?? '',
      description: List<String>.from(json['description'] ?? []),
      celebrityName: json['celebrity_name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      jobTags: List<String>.from(json['job_tags'] ?? []),
    );
  }
}