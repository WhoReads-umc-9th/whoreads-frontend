import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../celebrities/celebrities_book_page.dart';

class FollowListPage extends StatefulWidget {
  const FollowListPage({super.key});

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  bool isLoading = true;
  List<dynamic> follows = [];

  final Color primaryOrange = const Color(0xFFFF6A00);

  @override
  void initState() {
    super.initState();
    _fetchFollows();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIntimacyInfoSheet();
    });
  }

  Future<void> _fetchFollows() async {
    try {
      final response = await ApiClient.dio.get('/members/me/follows');

      if (response.statusCode == 200) {
        follows = response.data['result'] ?? [];
      }

      // 친밀도 높은 순으로 정렬
      follows.sort((a, b) => _intimacy(b).compareTo(_intimacy(a)));

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Follow List API Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  int? _toInt(dynamic value) => value is int ? value : int.tryParse('$value');

  int _intimacy(dynamic follow) {
    // 서버 스펙상 키가 intimacyScore 이지만 snake_case 변환 대비
    return _toInt(follow['intimacyScore'] ?? follow['intimacy_score']) ?? 0;
  }

  void _showIntimacyInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: Colors.black87, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '친밀도로 해당 인물이 나와\n얼마나 가까워졌는지 확인해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '친밀도는 이 인물이 추천한 책들 중에서,\n내가 완독한 책이 얼마나 되는지를 기준으로 계산돼요.\n읽은 책의 비율이 높을수록 친밀도도 함께 올라가요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          '팔로우 목록',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info, color: Color(0xFF9CA3AF), size: 26),
            onPressed: _showIntimacyInfoSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryOrange))
          : follows.isEmpty
              ? const Center(
                  child: Text('팔로우한 유명인이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: follows.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 20),
                  itemBuilder: (context, index) => _buildFollowRow(follows[index]),
                ),
    );
  }

  Widget _buildFollowRow(dynamic follow) {
    final int? celebrityId = _toInt(follow['id']);
    final String? imageUrl = follow['image_url'] as String?;

    return InkWell(
      onTap: celebrityId == null
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CelebritiesBookPage(celebrityId: celebrityId)),
              );
            },
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl == null || imageUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              follow['name']?.toString() ?? '이름 없음',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_intimacy(follow)}%',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
