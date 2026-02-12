import 'package:flutter/material.dart';
import '../../../models/book_model.dart';

class BookListItem extends StatelessWidget {
  final BookModel book;
  final bool showProgress;

  const BookListItem({
    super.key,
    required this.book,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 📕 책 표지
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: book.coverUrl != null
                ? Image.network(
              book.coverUrl!,
              width: 60,
              height: 80,
              fit: BoxFit.cover,
            )
                : Container(
              width: 60,
              height: 80,
              color: Colors.grey[300],
              child: const Icon(Icons.book),
            ),
          ),

          const SizedBox(width: 12),

          // 📖 제목 / 저자 / 진행률
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book.author,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                if (showProgress) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: book.progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${book.currentPage} / ${book.totalPages} 페이지',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}