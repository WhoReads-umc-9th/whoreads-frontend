import 'package:flutter/material.dart';
import 'package:whoreads/models/library_book_model.dart';

class BookListItem extends StatelessWidget {
  final LibraryBookModel book;
  final bool showProgress;
  final VoidCallback? onTap;   // 🔥 추가

  const BookListItem({
    super.key,
    required this.book,
    this.showProgress = false,
    this.onTap,                // 🔥 추가
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(   // 🔥 ripple 효과 위해 필요
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(   // 🔥 클릭 가능하게 변경
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
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
          ),
        ),
      ),
    );
  }
}
