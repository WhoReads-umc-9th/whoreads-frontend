import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const _documents = [
    (
      title: '서비스 이용약관',
      url: 'https://www.notion.so/3a8427c6192e806489a8f5c72799f376',
    ),
    (
      title: '개인정보 수집 및 이용에 대한 안내',
      url: 'https://www.notion.so/3a8427c6192e8068a905c521c0877420',
    ),
    (
      title: '이벤트 등 맞춤 혜택/정보 수신',
      url: 'https://www.notion.so/3a8427c6192e8034a481e8a423dfe3be',
    ),
  ];

  Future<void> _openDocument(BuildContext context, String url) async {
    try {
      if (await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // 브라우저를 실행할 수 없는 경우에도 현재 화면을 유지한다.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('페이지를 열 수 없습니다. 잠시 후 다시 시도해주세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('이용약관 / 개인정보수집 / 정보수신',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final document in _documents)
                  ListTile(
                    title: Text(document.title,
                        style: const TextStyle(fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 20),
                    onTap: () => _openDocument(context, document.url),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
