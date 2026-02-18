import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/token_storage.dart';

// --- 모델 클래스 ---
class CelebrityDetail {
  final int id;
  final String name;
  final String imageUrl;
  final String shortBio;
  final List<String> jobTags;

  CelebrityDetail({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.shortBio,
    required this.jobTags,
  });

  factory CelebrityDetail.fromJson(Map<String, dynamic> json) {
    return CelebrityDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '이름 없음',
      imageUrl: json['image_url'] ?? '',
      shortBio: json['short_bio'] ?? '',
      jobTags: List<String>.from(json['job_tags'] ?? []),
    );
  }
}

class CelebrityBook {
  final int bookId;
  final String title;
  final String coverUrl;
  final String author;

  CelebrityBook({
    required this.bookId,
    required this.title,
    required this.coverUrl,
    this.author = '',
  });

  factory CelebrityBook.fromJson(Map<String, dynamic> json) {
    return CelebrityBook(
      bookId: json['book_id'] ?? 0,
      title: json['book_title'] ?? '',
      coverUrl: json['book_cover'] ?? '',
      // 저자 정보가 없다면 빈 문자열
    );
  }
}

// ---------------------------------------------------------

class CelebritiesBookPage extends StatefulWidget {
  final int celebrityId;

  const CelebritiesBookPage({super.key, required this.celebrityId});

  @override
  State<CelebritiesBookPage> createState() => _CelebritiesBookPageState();
}

class _CelebritiesBookPageState extends State<CelebritiesBookPage> {
  bool isLoading = true;
  CelebrityDetail? celebrityProfile;
  List<CelebrityBook> bookList = [];
  final Set<int> _addedBookIds = {};
  final Color primaryOrange = const Color(0xFFFF6A00);

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    final token = await TokenStorage.getAccessToken();
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      final profileUrl = Uri.parse('http://43.201.122.162/api/celebrities/${widget.celebrityId}');
      final booksUrl = Uri.parse('http://43.201.122.162/api/quotes/celebrities/${widget.celebrityId}');

      final results = await Future.wait([
        http.get(profileUrl, headers: headers),
        http.get(booksUrl, headers: headers),
      ]);

      final profileResponse = results[0];
      final booksResponse = results[1];

      if (profileResponse.statusCode == 200 && booksResponse.statusCode == 200) {
        final profileData = jsonDecode(utf8.decode(profileResponse.bodyBytes));
        final booksData = jsonDecode(utf8.decode(booksResponse.bodyBytes));

        setState(() {
          celebrityProfile = CelebrityDetail.fromJson(profileData);
          if (booksData is List) {
            bookList = booksData.map((e) => CelebrityBook.fromJson(e)).toList();
          }
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00))),
      );
    }

    if (celebrityProfile == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text("정보를 불러올 수 없습니다.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 12, bottom: 12),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_alt_1, size: 14, color: Colors.white),
              label: const Text("팔로우", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32), // 버튼 높이 줄임
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // --- 프로필 섹션 ---
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: celebrityProfile!.imageUrl.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(celebrityProfile!.imageUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: Colors.grey[200],
                    ),
                    child: celebrityProfile!.imageUrl.isEmpty
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    celebrityProfile!.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: celebrityProfile!.jobTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      celebrityProfile!.shortBio.isNotEmpty
                          ? "\" ${celebrityProfile!.shortBio} \""
                          : "\" 한줄 소개가 없습니다. \"",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 20),

            // --- 책 목록 섹션 ---
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: bookList.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final book = bookList[index];
                final isAdded = _addedBookIds.contains(book.bookId);

                return SizedBox(
                  // [수정 포인트 1] 높이를 100으로 고정 (책 표지 높이와 동일)
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 책 표지
                      Container(
                        width: 70,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: book.coverUrl.isNotEmpty
                              ? Image.network(book.coverUrl, fit: BoxFit.cover)
                              : Container(color: Colors.grey[300], child: const Icon(Icons.book, color: Colors.grey)),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 책 정보 (Expanded로 남은 공간 차지)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, height: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              book.author.isNotEmpty ? book.author : '저자 미상',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // [수정 포인트 2] Column의 MainAxisAlignment.end를 사용하여 하단 정렬
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end, // 아래쪽 끝으로 정렬
                        children: [
                          isAdded
                              ? OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _addedBookIds.remove(book.bookId);
                              });
                            },
                            icon: const Icon(Icons.check, size: 14, color: Colors.grey),
                            label: const Text("추가됨", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              minimumSize: const Size(0, 30), // 높이 줄임
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 여백 제거
                            ),
                          )
                              : ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _addedBookIds.add(book.bookId);
                              });
                            },
                            icon: const Icon(Icons.add, size: 14, color: Colors.white),
                            label: const Text("추가", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8A65),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                              // [수정 포인트 3] 버튼 크기 축소
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              minimumSize: const Size(0, 30), // 높이 30으로 고정
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 터치 영역 여백 제거
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}