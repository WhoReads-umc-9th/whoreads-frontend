import 'package:flutter/material.dart';

class SavedTab extends StatelessWidget {
  const SavedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List books = []; // TODO: API 연결

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('아직 담아둔 책이 없어요'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              child: const Text('추천 책 보러 가기'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (_, index) {
        return ListTile(title: Text(books[index].title));
      },
    );
  }
}
