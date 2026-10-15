import 'package:flutter/material.dart';

import '../../models/dna_models.dart';
import '../celebrities/celebrities_book_page.dart';
import 'dna_test_page.dart';

class DnaResultPage extends StatefulWidget {
  final DnaResult result;

  const DnaResultPage({super.key, required this.result});

  @override
  State<DnaResultPage> createState() => _DnaResultPageState();
}

class _DnaResultPageState extends State<DnaResultPage> {
  late DnaResult _result = widget.result;

  Future<void> _retest() async {
    final result = await Navigator.of(context).push<DnaResult>(
      MaterialPageRoute(builder: (_) => const DnaTestPage(returnResult: true)),
    );
    if (mounted && result != null) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final headline =
        RegExp(r"'(.*?)'").firstMatch(_result.headline)?.group(0) ??
        _result.headline;
    final job = _result.jobTags.isEmpty ? '' : '${_result.jobTags.first} ';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '독서 DNA 테스트 결과',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            const Text(
              '지금 당신은',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6A00),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '독서를 하는 사람입니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            for (final description in _result.description)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              '이 유형에 속하는 인물',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Center(
              child: ClipOval(
                child: _result.imageUrl.isEmpty
                    ? const SizedBox(
                        width: 120,
                        height: 120,
                        child: Icon(Icons.person, size: 60, color: Colors.grey),
                      )
                    : Image.network(
                        _result.imageUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => const SizedBox(
                          width: 120,
                          height: 120,
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$job${_result.celebrityName}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CelebritiesBookPage(celebrityId: _result.celebrityId),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C22),
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                '${_result.celebrityName}의 추천 도서 확인하기',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _retest,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1C1C22),
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '다시 테스트하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
