import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/book/QuoteCard.dart';
import '../../core/network/api_client.dart';

class BookDetailPage extends StatefulWidget {
  final int bookId;

  const BookDetailPage({
    super.key,
    required this.bookId,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  bool isLoading = true;

  // 파싱할 데이터 변수들
  String? title;
  String? authorName;
  String? coverUrl;
  String? genre;
  String? link;
  int? totalPage;
  int? readingPage;
  String? startedAt;
  String? completedAt;
  String readingStatus = "NONE";
  List<dynamic> quotes = [];

  // 서재 책 고유 ID (수정 및 삭제 API에 필요함)
  int? userBookId;

  // 수정 모드 관련 상태 변수들
  bool isEditing = false;
  String editStatus = "NONE";
  late TextEditingController pageController;

  @override
  void initState() {
    super.initState();
    pageController = TextEditingController();
    _fetchBookDetail();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookDetail() async {
    try {
      final response = await ApiClient.dio.get(
        '/books/${widget.bookId}/detail',
      );

      if (response.statusCode == 200) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final result = decoded['result'] ?? {};
        final readingInfo = result['reading_info'] ?? {};

        setState(() {
          title = result['title'];
          authorName = result['author_name'];
          coverUrl = result['cover_url'];
          genre = result['genre'];
          link = result['link'];

          readingStatus = readingInfo['reading_status'] ?? "NONE";
          readingPage = readingInfo['reading_page'];
          totalPage = readingInfo['total_page'];
          startedAt = readingInfo['started_at'];
          completedAt = readingInfo['completed_at'];

          userBookId = readingInfo['user_book_id'];

          quotes = result['quotes'] ?? [];

          isLoading = false;
        });
      } else {
        debugPrint('상세 페이지 API 에러: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('네트워크 에러: $e');
      setState(() => isLoading = false);
    }
  }

  // 🌟 [새로 추가됨] 서재에 책 추가 API 호출 (POST)
  Future<void> _addBook() async {
    try {
      final response = await ApiClient.dio.post(
        '/me/library/book/${widget.bookId}',
      );

      // 201 Created 또는 200 OK
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;

        setState(() {
          // 🌟 서버에서 내려준 새로 생성된 user_book_id 저장!
          userBookId = decoded['result']['user_book_id'];
          // 🌟 책이 추가되었으므로 기본 상태를 '담아둠(WISH)'으로 변경
          readingStatus = 'WISH';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서재에 책을 담았습니다!')),
          );
        }
      } else {
        debugPrint('추가 실패: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      debugPrint('추가 에러: $e');
    }
  }

  // 서재에서 책 삭제 API 호출 (DELETE)
  Future<void> _deleteBook() async {
    if (userBookId == null) {
      debugPrint('삭제할 userBookId가 없습니다.');
      return;
    }

    try {
      final response = await ApiClient.dio.delete(
        '/me/library/book/$userBookId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          readingStatus = 'NONE';
          userBookId = null; // 삭제되었으므로 userBookId 초기화
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서재에서 삭제되었습니다.')),
          );
        }
      } else {
        debugPrint('삭제 실패: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      debugPrint('삭제 에러: $e');
    }
  }

  // 수정 내용 저장 API 호출 (PATCH)
  Future<void> _saveChanges() async {
    try {
      // 🌟 저장해둔 userBookId를 사용해서 PATCH 요청
      final targetId = userBookId ?? widget.bookId;

      Map<String, dynamic> body = {
        "reading_status": editStatus,
      };

      if (editStatus == 'READING') {
        body["reading_page"] = int.tryParse(pageController.text) ?? 0;
      }

      final response = await ApiClient.dio.patch(
        '/me/library/book/$targetId',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          readingStatus = editStatus;
          if (editStatus == 'READING') {
            readingPage = int.tryParse(pageController.text) ?? readingPage;
          } else if (editStatus == 'COMPLETE') {
            readingPage = totalPage;
          }
          isEditing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('수정이 완료되었습니다.')),
          );
        }
      } else {
        debugPrint('수정 실패: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      debugPrint('수정 에러: $e');
    }
  }

  Widget _buildStatusButton(String label, String value) {
    final String currentStatus = isEditing ? editStatus : readingStatus;
    final isSelected = currentStatus == value ||
        (value == "COMPLETE" && currentStatus == "DONE");

    return GestureDetector(
      onTap: () {
        if (isEditing) {
          setState(() {
            editStatus = value;
            if (value == 'COMPLETE') {
              pageController.text = (totalPage ?? 0).toString();
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8A5B) : Colors.grey[200],
          borderRadius: BorderRadius.circular(52),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF84E00),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReadingProgressAndPeriod() {
    final int current = readingPage ?? 0;
    final int total = (totalPage != null && totalPage! > 0) ? totalPage! : 1;
    final double progress = current / total;
    final int percent = (progress * 100).toInt();

    final String formattedStart = startedAt?.replaceAll('-', '.') ?? '-';
    final String formattedEnd = completedAt?.replaceAll('-', '.') ?? '-';

    if (!isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('독서량', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF84E00)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$percent%', style: const TextStyle(color: Color(0xFFF84E00), fontWeight: FontWeight.bold, fontSize: 14)),
              Text('$current/${totalPage ?? 0}p', style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('독서 기간', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF84E00)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('시작', style: TextStyle(color: Color(0xFFF84E00), fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 12),
                Expanded(child: Text(formattedStart, style: const TextStyle(color: Colors.black87, fontSize: 14))),

                const Text('종료', style: TextStyle(color: Color(0xFFF84E00), fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 12),
                Expanded(child: Text(formattedEnd, style: const TextStyle(color: Colors.black87, fontSize: 14))),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('독서량', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),

          if (editStatus == 'READING')
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF84E00)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: pageController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        final p = int.tryParse(val) ?? 0;
                        if (totalPage != null && p >= totalPage!) {
                          setState(() {
                            pageController.text = totalPage.toString();
                            editStatus = 'COMPLETE';
                          });
                        }
                      },
                    ),
                  ),
                  Text(' / ${totalPage ?? 0}p', style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  editStatus == 'COMPLETE' ? '${totalPage ?? 0} / ${totalPage ?? 0}p' : '0 / ${totalPage ?? 0}p',
                  style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          const SizedBox(height: 24),
          const Text('독서 기간', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('시작', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(formattedStart, style: const TextStyle(color: Colors.grey, fontSize: 14))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('종료', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(formattedEnd, style: const TextStyle(color: Colors.grey, fontSize: 14))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8A5B))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          // 🌟 상태가 NONE(내 서재에 없음)일 때는 '추가' 버튼 표시
          if (readingStatus == 'NONE' && !isEditing)
            TextButton(
              // 🌟 [수정됨] 추가 버튼 누르면 POST API 호출하도록 연동
              onPressed: _addBook,
              child: const Text('추가', style: TextStyle(color: Color(0xFFF84E00), fontSize: 16, fontWeight: FontWeight.bold)),
            )
          else if (isEditing)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('저장', style: TextStyle(color: Color(0xFFF84E00), fontSize: 16, fontWeight: FontWeight.bold)),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Colors.black),
              onSelected: (value) {
                if (value == 'edit') {
                  setState(() {
                    isEditing = true;
                    editStatus = readingStatus;
                    pageController.text = (readingPage ?? 0).toString();
                  });
                } else if (value == 'delete') {
                  _deleteBook();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('수정')),
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(2, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          coverUrl ?? '', width: 110, height: 160, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(width: 110, height: 160, color: Colors.grey[200], child: const Icon(Icons.book, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title ?? '제목 없음', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(authorName ?? '작자 미상', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              _buildStatusButton("담아둠", "WISH"),
                              const SizedBox(width: 4),
                              _buildStatusButton("읽는 중", "READING"),
                              const SizedBox(width: 4),
                              _buildStatusButton("다 읽음", "COMPLETE"),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (genre != null && genre!.isNotEmpty)
                            _buildTag(genre!),

                          const SizedBox(height: 12),

                          GestureDetector(
                            onTap: () async {
                              if (link != null && link!.isNotEmpty) {
                                final uri = Uri.parse(link!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              }
                            },
                            child: const Text("책 더 자세히 보기", style: TextStyle(color: Color(0xFFF84E00), fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: Color(0xFFF84E00))),
                          ),
                        ],
                      ),
                    )
                  ],
                ),

                if (isEditing || readingStatus == 'READING' || readingStatus == 'DONE' || readingStatus == 'COMPLETE') ...[
                  const SizedBox(height: 24),
                  _buildReadingProgressAndPeriod(),
                  const SizedBox(height: 24),
                ] else ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text("이 책을 읽으면 아래 유명인들과 더 친밀해질 수 있어요!", style: TextStyle(fontSize: 13, color: Colors.black87))),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(thickness: 1, height: 1, color: Color(0xFFE5E7EB)),
          ),

          Expanded(
            child: quotes.isEmpty
                ? const Center(child: Text('등록된 추천사가 없습니다.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: quotes.length,
              itemBuilder: (context, index) {
                final quoteData = quotes[index];
                final celeb = quoteData['celebrity'] ?? {};
                final source = quoteData['source'] ?? {};
                final List<dynamic> jobTags = celeb['job_tags'] ?? [];
                final String job = jobTags.isNotEmpty ? jobTags.first : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: QuoteCard(
                    profileImage: celeb['image_url'] ?? 'https://i.pravatar.cc/150',
                    name: celeb['name'] ?? '유명인',
                    job: job,
                    quote: quoteData['original_text'] ?? '',
                    source: source['type'] == 'INTERVIEW' ? '인터뷰 발췌' : '추천사 출처',
                    sourceUrl: source['url'],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}