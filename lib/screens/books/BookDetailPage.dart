import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/book/QuoteCard.dart';
import '../../core/network/api_client.dart';
import '../../services/library_service.dart';

class BookDetailPage extends StatefulWidget {
  final int bookId;

  const BookDetailPage({super.key, required this.bookId});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  bool isLoading = true;
  bool _mutating = false;
  String? _loadError;

  void _showFailure(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

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

  @override
  void initState() {
    super.initState();
    _fetchBookDetail();
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  int? _readInt(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }
    return null;
  }

  DateTime _today() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// `2026-05-16T12:34:56` → `2026-05-16`
  String? _toApiDateOnly(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final value = raw.trim();
    if (value.length < 10) return null;
    final dateOnly = value.substring(0, 10);
    final parsed = DateTime.tryParse(dateOnly);
    if (parsed == null || _formatDate(parsed) != dateOnly) return null;
    return dateOnly;
  }

  Future<void> _fetchBookDetail({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) isLoading = true;
      _loadError = null;
    });
    try {
      final response = await ApiClient.checked(
        ApiClient.dio.get('/books/${widget.bookId}/detail'),
      );

      if (response.statusCode == 200) {
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final result = decoded['result'] ?? {};
        final readingInfo = _asStringKeyMap(
          result['reading_info'] ?? result['readingInfo'],
        );

        String nextStatus =
            readingInfo?['reading_status']?.toString() ??
            readingInfo?['readingStatus']?.toString() ??
            'NONE';
        if (nextStatus.isEmpty) nextStatus = 'NONE';

        int? nextUserBookId = _readInt(readingInfo, [
          'user_book_id',
          'userBookId',
        ]);
        int? nextReadingPage = _readInt(readingInfo, [
          'reading_page',
          'readingPage',
        ]);
        int? nextTotalPage = _readInt(readingInfo, ['total_page', 'totalPage']);
        String? nextStarted =
            readingInfo?['started_at']?.toString() ??
            readingInfo?['startedAt']?.toString();
        String? nextCompleted =
            readingInfo?['completed_at']?.toString() ??
            readingInfo?['completedAt']?.toString();

        final snapshot = nextUserBookId == null
            ? await LibraryService.lookupCatalogBookInLibrary(widget.bookId)
            : null;
        if (snapshot != null) {
          nextUserBookId ??= snapshot.userBookId;
          if (nextStatus == 'NONE') {
            nextStatus = snapshot.readingStatus;
          }
          nextReadingPage ??= snapshot.readingPage;
          nextTotalPage ??= snapshot.totalPage;
        }

        final resultMap = _asStringKeyMap(result);
        nextTotalPage ??= _readInt(resultMap, ['total_page', 'totalPage']);
        // In reading_info, an omitted date means no saved date.
        if (readingInfo == null) {
          nextStarted ??= snapshot?.startedAt;
          nextCompleted ??= snapshot?.completedAt;
        }

        if (!mounted) return;

        setState(() {
          title = result['title'];
          authorName = result['author_name'];
          coverUrl = result['cover_url'];
          genre = result['genre'];
          link = result['link'];

          readingStatus = nextStatus == 'DONE' ? 'COMPLETE' : nextStatus;
          readingPage = nextReadingPage;
          totalPage = nextTotalPage;
          startedAt = _toApiDateOnly(nextStarted);
          completedAt = _toApiDateOnly(nextCompleted);

          userBookId = nextUserBookId;

          quotes = result['quotes'] ?? [];

          isLoading = false;
        });
      } else {
        if (!mounted) return;
        if (showLoading) {
          setState(() {
            _loadError = '도서 정보를 불러오지 못했습니다.';
            isLoading = false;
          });
        } else {
          _showFailure('저장은 완료했지만 최신 정보를 불러오지 못했습니다.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _loadError = '도서 정보를 불러오지 못했습니다.';
          isLoading = false;
        });
      } else {
        _showFailure('저장은 완료했지만 최신 정보를 불러오지 못했습니다.');
      }
    }
  }

  Future<void> _addBook() => _changeStatus('WISH');

  // 서재에서 책 삭제 API 호출 (DELETE)
  Future<void> _deleteBook() async {
    if (_mutating) return;
    if (!mounted) return;
    setState(() => _mutating = true);
    try {
      if (userBookId == null) {
        _showFailure('서재 정보를 확인할 수 없습니다. 다시 불러와주세요.');
        return;
      }

      try {
        final response = await ApiClient.dio.delete(
          '/me/library/book/$userBookId',
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          if (!mounted) return;
          setState(() {
            readingStatus = 'NONE';
            userBookId = null; // 삭제되었으므로 userBookId 초기화
            readingPage = null;
            startedAt = null;
            completedAt = null;
          });

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('서재에서 삭제되었습니다.')));
          }
        } else {
          _showFailure('저장하지 못했습니다. 연결을 확인하고 다시 시도해주세요.');
        }
      } catch (e) {
        _showFailure('저장하지 못했습니다. 연결을 확인하고 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _showInputError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('입력할 수 없습니다'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _errorMessage(dynamic data) {
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return '저장하지 못했습니다. 연결을 확인하고 다시 시도해주세요.';
      }
    }
    final message = data is Map ? data['message'] : null;
    return message is String && message.trim().isNotEmpty
        ? message
        : '저장하지 못했습니다. 연결을 확인하고 다시 시도해주세요.';
  }

  String? _dateError(Map<String, dynamic> body) {
    for (final key in ['started_at', 'completed_at']) {
      if (!body.containsKey(key)) continue;
      final raw = body[key] as String;
      final date = DateTime.tryParse(raw);
      if (date == null || _formatDate(date) != raw) {
        return '올바른 날짜를 선택해주세요.';
      }
      if (date.isAfter(_today())) return '미래 날짜는 입력할 수 없습니다.';
    }
    final start = body['started_at'] as String? ?? startedAt;
    final end = body['completed_at'] as String? ?? completedAt;
    if (start == null || end == null || start.compareTo(end) <= 0) {
      return null;
    }
    final status = body['reading_status'] as String? ?? readingStatus;
    // Only this request shape allows the server to clear an old completion date.
    if (status == 'READING' &&
        body.containsKey('started_at') &&
        !body.containsKey('completed_at')) {
      return null;
    }
    return '시작일은 완료일보다 늦을 수 없습니다. 완료일을 먼저 수정해주세요.';
  }

  Future<void> _changeStatus(String status) async {
    if (_mutating || readingStatus == status) return;
    final today = _formatDate(_today());
    final body = <String, dynamic>{'reading_status': status};
    if (status == 'READING' && startedAt == null) {
      body['started_at'] = today;
    } else if (status == 'COMPLETE') {
      if (startedAt == null) body['started_at'] = completedAt ?? today;
      if (completedAt == null) body['completed_at'] = today;
    }
    await _persistUpdate(body);
  }

  Future<void> _persistUpdate(Map<String, dynamic> body) async {
    if (_mutating || !mounted) return;
    final validationError = _dateError(body);
    if (validationError != null) {
      await _showInputError(validationError);
      return;
    }
    setState(() => _mutating = true);
    try {
      if (userBookId == null && readingStatus == 'NONE') {
        final response = await ApiClient.checked(
          ApiClient.dio.post('/me/library/book/${widget.bookId}'),
        );
        final decoded = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final result = _asStringKeyMap(decoded?['result']);
        if (!mounted) return;
        setState(() {
          userBookId = _readInt(result, ['user_book_id', 'userBookId']);
          readingStatus = 'WISH';
          readingPage = null;
          startedAt = null;
          completedAt = null;
        });
        if (userBookId == null || body['reading_status'] == 'WISH') {
          await _fetchBookDetail(showLoading: false);
        }
        if (!mounted || body['reading_status'] == 'WISH') return;
      }
      if (userBookId == null) {
        _showFailure('서재 정보를 확인할 수 없습니다. 다시 불러와주세요.');
        return;
      }
      await ApiClient.checked(
        ApiClient.dio.patch('/me/library/book/$userBookId', data: body),
      );
      if (!mounted) return;
      setState(() {
        readingStatus = body['reading_status'] as String? ?? readingStatus;
        readingPage = body['reading_page'] as int? ?? readingPage;
        startedAt = body['started_at'] as String? ?? startedAt;
        completedAt = body['completed_at'] as String? ?? completedAt;
        if (readingStatus == 'READING' &&
            body.containsKey('started_at') &&
            !body.containsKey('completed_at') &&
            completedAt != null &&
            startedAt!.compareTo(completedAt!) > 0) {
          completedAt = null;
        }
      });
      await _fetchBookDetail(showLoading: false);
    } on DioException catch (error) {
      if (error.response?.statusCode == 400) {
        await _showInputError(_errorMessage(error.response?.data));
      } else {
        _showFailure(_errorMessage(error.response?.data));
      }
    } catch (_) {
      _showFailure('저장하지 못했습니다. 연결을 확인하고 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editDate({required bool isStart}) async {
    if (_mutating) return;
    final saved = isStart ? startedAt : completedAt;
    final today = _today();
    final savedDate = DateTime.tryParse(saved ?? '');
    final initial = savedDate == null || savedDate.isAfter(today)
        ? today
        : savedDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(DateTime(1900)) ? initial : DateTime(1900),
      lastDate: today,
      helpText: isStart ? '시작일 선택' : '완료일 선택',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (selected == null || !mounted) return;
    final value = _formatDate(selected);
    if (value == saved) return;
    await _persistUpdate({isStart ? 'started_at' : 'completed_at': value});
  }

  Future<void> _editReadingPage() async {
    if (_mutating || readingStatus != 'READING') return;
    final formKey = GlobalKey<FormState>();
    var draft = _validReadingPage?.toString() ?? '';
    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('읽은 페이지 수정'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: draft,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '읽은 페이지',
              suffixText: totalPage == null ? 'p' : '/ $totalPage p',
            ),
            onChanged: (value) => draft = value,
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed < 1) {
                return '읽은 페이지는 1 이상이어야 합니다.';
              }
              if (totalPage != null && parsed > totalPage!) {
                return '전체 페이지 수를 초과할 수 없습니다.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, int.parse(draft.trim()));
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (page == null || !mounted || page == readingPage) return;
    await _persistUpdate({'reading_page': page});
  }

  int? get _validReadingPage {
    final page = readingPage;
    if (page == null || page < 1 || (totalPage != null && page > totalPage!)) {
      return null;
    }
    return page;
  }

  Widget _buildStatusButton(String label, String value) {
    final isSelected = readingStatus == value;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !_mutating,
      child: GestureDetector(
        onTap: _mutating ? null : () => _changeStatus(value),
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

  Widget _buildDateField(String label, String? value, {required bool isStart}) {
    final enabled = !_mutating && (isStart || readingStatus == 'COMPLETE');
    return Expanded(
      child: InkWell(
        onTap: enabled ? () => _editDate(isStart: isStart) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF84E00),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value?.replaceAll('-', '.') ?? '-',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
              ),
              if (enabled)
                const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingProgressAndPeriod() {
    final isComplete = readingStatus == 'COMPLETE';
    final current = isComplete ? totalPage : _validReadingPage;
    final total = totalPage ?? 0;
    final progress = total > 0 ? ((current ?? 0) / total).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '독서량',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (readingStatus == 'READING')
              TextButton(
                onPressed: _mutating ? null : _editReadingPage,
                child: const Text('페이지 수정'),
              ),
          ],
        ),
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
            Text(
              '$percent%',
              style: const TextStyle(
                color: Color(0xFFF84E00),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              '${current ?? '-'}/${totalPage ?? '-'}p',
              style: const TextStyle(color: Color(0xFF4B5563), fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          '독서 기간',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF84E00)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildDateField('시작', startedAt, isStart: true),
              _buildDateField(
                '종료',
                isComplete ? completedAt : null,
                isStart: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8A5B)),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!),
              TextButton(
                onPressed: _fetchBookDetail,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          if (readingStatus == 'NONE')
            TextButton(
              onPressed: _mutating ? null : _addBook,
              child: const Text(
                '추가',
                style: TextStyle(
                  color: Color(0xFFF84E00),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              enabled: !_mutating,
              icon: const Icon(Icons.more_horiz, color: Colors.black),
              onSelected: (value) {
                if (value == 'delete') _deleteBook();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
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
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 5,
                                  offset: const Offset(2, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                coverUrl ?? '',
                                width: 110,
                                height: 160,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 110,
                                      height: 160,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.book,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title ?? '제목 없음',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  authorName ?? '작자 미상',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _buildStatusButton("담아둠", "WISH"),
                                    _buildStatusButton("읽는 중", "READING"),
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
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    }
                                  },
                                  child: const Text(
                                    "책 더 자세히 보기",
                                    style: TextStyle(
                                      color: Color(0xFFF84E00),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Color(0xFFF84E00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (readingStatus == 'READING' ||
                          readingStatus == 'COMPLETE') ...[
                        const SizedBox(height: 24),
                        _buildReadingProgressAndPeriod(),
                        const SizedBox(height: 24),
                      ] else ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "이 책을 읽으면 아래 유명인들과 더 친밀해질 수 있어요!",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    thickness: 1,
                    height: 1,
                    color: Color(0xFFE5E7EB),
                  ),
                ),
              ],
            ),
          ),
          if (quotes.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '등록된 추천사가 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              sliver: SliverList.builder(
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
                      profileImage:
                          celeb['image_url'] ?? 'https://i.pravatar.cc/150',
                      name: celeb['name'] ?? '유명인',
                      job: job,
                      quote: quoteData['original_text'] ?? '',
                      source: source['type'] == 'INTERVIEW'
                          ? '인터뷰 발췌'
                          : '추천사 출처',
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
