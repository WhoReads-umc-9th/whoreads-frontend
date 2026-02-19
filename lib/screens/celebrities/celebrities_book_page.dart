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
  final bool isFollowing; // 🌟 [추가됨] 팔로우 상태 파싱용

  CelebrityDetail({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.shortBio,
    required this.jobTags,
    this.isFollowing = false,
  });

  factory CelebrityDetail.fromJson(Map<String, dynamic> json) {
    return CelebrityDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '이름 없음',
      imageUrl: json['image_url'] ?? '',
      shortBio: json['short_bio'] ?? '',
      jobTags: List<String>.from(json['job_tags'] ?? []),
      // 서버에서 팔로우 여부를 내려준다면 파싱, 없으면 기본값 false
      isFollowing: json['is_following'] ?? json['is_followed'] ?? false,
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
    final bookNode = json['book'] ?? json;

    return CelebrityBook(
      bookId: bookNode['id'] ?? bookNode['book_id'] ?? json['book_id'] ?? 0,
      title: bookNode['title'] ?? bookNode['book_title'] ?? json['book_title'] ?? '제목 없음',
      coverUrl: bookNode['cover_url'] ?? bookNode['book_cover'] ?? json['book_cover'] ?? '',
      author: bookNode['author_name'] ?? bookNode['author'] ?? json['author'] ?? '저자 미상',
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

  // bookId를 키(key)로, userBookId를 값(value)으로 저장하는 Map
  final Map<int, int> _addedBooksMap = {};

  // 🌟 [추가됨] 팔로우 상태 관리를 위한 변수
  bool isFollowing = false;

  final Color primaryOrange = const Color(0xFFFF6A00);

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    final token = await TokenStorage.getAccessToken();
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      final profileUrl = Uri.parse('http://43.201.122.162/api/celebrities/${widget.celebrityId}');
      final booksUrl = Uri.parse('http://43.201.122.162/api/quotes/celebrities/${widget.celebrityId}');
      final libraryUrl = Uri.parse('http://43.201.122.162/api/me/library/list?status=WISH&size=100');

      final results = await Future.wait([
        http.get(profileUrl, headers: headers),
        http.get(booksUrl, headers: headers),
        http.get(libraryUrl, headers: headers),
      ]);

      final profileResponse = results[0];
      final booksResponse = results[1];
      final libraryResponse = results[2];

      if (profileResponse.statusCode == 200 && booksResponse.statusCode == 200) {
        final profileData = jsonDecode(utf8.decode(profileResponse.bodyBytes));
        final booksData = jsonDecode(utf8.decode(booksResponse.bodyBytes));

        if (libraryResponse.statusCode == 200) {
          final libraryData = jsonDecode(utf8.decode(libraryResponse.bodyBytes));
          final resultData = libraryData['result'];
          List<dynamic> libraryItems = [];

          if (resultData is List) {
            libraryItems = resultData;
          } else if (resultData is Map) {
            if (resultData.containsKey('content')) libraryItems = resultData['content'];
            else if (resultData.containsKey('books')) libraryItems = resultData['books'];
          }

          for (var item in libraryItems) {
            int? bId = item['book_id'] ?? (item['book'] != null ? item['book']['id'] : null);
            int? uBId = item['user_book_id'] ?? item['id'];

            if (bId != null && uBId != null) {
              _addedBooksMap[bId] = uBId;
            }
          }
        }

        setState(() {
          celebrityProfile = CelebrityDetail.fromJson(profileData);
          // 🌟 프로필 데이터에서 현재 팔로우 상태 초기화
          isFollowing = celebrityProfile!.isFollowing;

          if (booksData is List) {
            bookList = booksData.map((e) => CelebrityBook.fromJson(e)).toList();
          } else if (booksData is Map && booksData.containsKey('result')) {
            final resultData = booksData['result'];
            if (resultData is List) {
              bookList = resultData.map((e) => CelebrityBook.fromJson(e)).toList();
            }
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

  // 🌟 [추가됨] 유명인 팔로우 / 언팔로우 API (POST / DELETE)
  Future<void> _toggleFollow() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final uri = Uri.parse('http://43.201.122.162/api/members/follow/${widget.celebrityId}');
      final headers = {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      if (isFollowing) {
        // 이미 팔로우 중이면 취소 (DELETE)
        final response = await http.delete(uri, headers: headers);
        if (response.statusCode == 200 || response.statusCode == 204) {
          setState(() => isFollowing = false);
        } else {
          debugPrint('언팔로우 실패: ${response.statusCode}');
        }
      } else {
        // 팔로우 안 했으면 추가 (POST)
        final response = await http.post(uri, headers: headers);
        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() => isFollowing = true);
        } else {
          debugPrint('팔로우 실패: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('팔로우 에러: $e');
    }
  }

  // 서재에 책 추가 API 호출 (POST)
  Future<void> _addBookToLibrary(int bookId) async {
    if (bookId == 0) return;

    try {
      final token = await TokenStorage.getAccessToken();
      final uri = Uri.parse('http://43.201.122.162/api/me/library/book/$bookId');

      final response = await http.post(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final int? newUserBookId = decoded['result']?['user_book_id'];

        setState(() {
          if (newUserBookId != null) {
            _addedBooksMap[bookId] = newUserBookId;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서재에 담아둠으로 추가되었습니다!')),
          );
        }
      } else {
        debugPrint('책 추가 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('책 추가 에러: $e');
    }
  }

  // 서재에서 책 삭제 API 호출 (DELETE)
  Future<void> _removeBookFromLibrary(int bookId) async {
    final userBookId = _addedBooksMap[bookId];
    if (userBookId == null) return;

    try {
      final token = await TokenStorage.getAccessToken();
      final uri = Uri.parse('http://43.201.122.162/api/me/library/book/$userBookId');

      final response = await http.delete(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _addedBooksMap.remove(bookId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서재에서 삭제되었습니다.')),
          );
        }
      } else {
        debugPrint('책 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('책 삭제 에러: $e');
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
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text("정보를 불러올 수 없습니다.")),
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
            // 🌟 [수정됨] 팔로우 상태에 따른 버튼 UI 변경
            child: isFollowing
                ? OutlinedButton.icon(
              onPressed: _toggleFollow,
              icon: const Icon(Icons.person, size: 14, color: Colors.grey),
              label: const Text("팔로우", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
              ),
            )
                : ElevatedButton.icon(
              onPressed: _toggleFollow,
              icon: const Icon(Icons.person_add_alt_1, size: 14, color: Colors.white),
              label: const Text("팔로우", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
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
            bookList.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('추천된 책이 없습니다.', style: TextStyle(color: Colors.grey)),
            )
                : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: bookList.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final book = bookList[index];

                final isAdded = _addedBooksMap.containsKey(book.bookId);

                return SizedBox(
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
                              ? Image.network(
                            book.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.book, color: Colors.grey)),
                          )
                              : Container(color: Colors.grey[200], child: const Icon(Icons.book, color: Colors.grey)),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 책 정보
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

                      // 오른쪽 하단 버튼들
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          isAdded
                              ? OutlinedButton.icon(
                            onPressed: () => _removeBookFromLibrary(book.bookId),
                            icon: const Icon(Icons.check, size: 14, color: Colors.grey),
                            label: const Text("추가됨", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                              : ElevatedButton.icon(
                            onPressed: () => _addBookToLibrary(book.bookId),
                            icon: const Icon(Icons.add, size: 14, color: Colors.white),
                            label: const Text("추가", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8A65),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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