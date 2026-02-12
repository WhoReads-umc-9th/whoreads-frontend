import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CelebrityDetailPage extends StatefulWidget {
  final int celebrityId;

  const CelebrityDetailPage({
    super.key,
    required this.celebrityId,
  });

  @override
  State<CelebrityDetailPage> createState() => _CelebrityDetailPageState();
}

class _CelebrityDetailPageState extends State<CelebrityDetailPage> {
  bool isLoading = true;
  Map<String, dynamic>? celebrity;

  /// 임시 책 데이터 (추후 API로 교체)
  final List<Map<String, dynamic>> books = [
    {
      'image': 'https://via.placeholder.com/80x120',
      'title': '떠난 것은 돌아오지 않는다',
      'author': '줄리언 반스',
      'added': false,
    },
    {
      'image': 'https://via.placeholder.com/80x120',
      'title': '이야기를 들려줘요',
      'author': '엘리자베스 스트라우트',
      'added': true,
    },
    {
      'image': 'https://via.placeholder.com/80x120',
      'title': '뇌는 어떻게 나를 조종하는가',
      'author': '크리스 나이바우어',
      'added': true,
    },
    {
      'image': 'https://via.placeholder.com/80x120',
      'title': '인간 본성의 법칙',
      'author': '로버트 그린',
      'added': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    fetchCelebrityDetail();
  }

  Future<void> fetchCelebrityDetail() async {
    final uri = Uri.parse(
      'https://your-domain.com/api/celebrities/${widget.celebrityId}',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      setState(() {
        celebrity = jsonDecode(utf8.decode(response.bodyBytes));
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// ================= AppBar =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('팔로우'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),

            /// ================= 프로필 =================
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                celebrity!['image_url'],
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              celebrity!['name'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            /// ================= 직업 태그 =================
            Wrap(
              spacing: 8,
              children: (celebrity!['job_tags'] as List)
                  .take(2)
                  .map<Widget>((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            /// ================= 한줄 소개 =================
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                celebrity!['short_bio'],
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),

            /// ================= 책 리스트 =================
            ListView.builder(
              itemCount: books.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final book = books[index];
                return _BookItem(
                  book: book,
                  onToggle: () {
                    setState(() {
                      book['added'] = !book['added'];
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= 책 아이템 =================
class _BookItem extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onToggle;

  const _BookItem({
    required this.book,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool added = book['added'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            book['image'],
            width: 70,
            height: 100,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book['author'],
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          ElevatedButton.icon(
            onPressed: added ? null : onToggle,
            icon: Icon(
              added ? Icons.check : Icons.add,
              size: 16,
            ),
            label: Text(added ? '추가됨' : '추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              added ? Colors.grey.shade300 : Colors.orange,
              foregroundColor:
              added ? Colors.grey.shade700 : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
