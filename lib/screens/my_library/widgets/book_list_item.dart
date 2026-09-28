import 'package:flutter/material.dart';
import 'package:whoreads/models/library_book_model.dart';

class BookListItem extends StatelessWidget {
  final LibraryBookModel book;
  final bool showProgress;
  final VoidCallback? onTap;

  const BookListItem({
    super.key,
    required this.book,
    this.showProgress = false,
    this.onTap,
  });

  Widget _buildCelebrityStack() {
    if (book.celebritiesCount == 0) return const SizedBox.shrink();

    // 최대 3명까지만 표시
    final displayCelebrities = book.celebrities.take(3).toList();
    const double avatarSize = 28.0; // 프로필 이미지 크기
    const double overlap = 10.0; // 겹치는 정도

    return SizedBox(
      width:
          (avatarSize - overlap) * (displayCelebrities.length - 1) + avatarSize,
      height: avatarSize,
      child: Stack(
        children: List.generate(displayCelebrities.length, (index) {
          return Positioned(
            left: index * (avatarSize - overlap), // 인덱스만큼 오른쪽으로 이동
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5), // 흰색 테두리
                image: DecorationImage(
                  image: NetworkImage(displayCelebrities[index].profileUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progressValue = book.progress;
    final int progressPercent = (progressValue * 100).toInt();

    return Material(
      color: Colors.white, // 배경색
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // [수정 2] 아이템 내부 여백 (위아래 마진은 없애고, 내부 콘텐츠 간격만 유지)
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // 텍스트 위쪽 정렬
            children: [
              // [수정 3] 이미지에만 그림자(Shadow) 적용
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8), // 이미지 둥글기랑 맞춤
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15), // 연한 그림자
                      blurRadius: 5,
                      offset: const Offset(2, 4), // 오른쪽 아래 그림자
                    ),
                  ],
                ),
                child: ClipRRect(
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
                          child: const Icon(Icons.book, color: Colors.grey),
                        ),
                ),
              ),

              const SizedBox(width: 16), // 이미지와 텍스트 사이 간격 약간 넓힘
              // 텍스트 정보 (Expanded로 남은 공간 채움)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),

                    if (showProgress) ...[
                      const SizedBox(height: 12),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE5E7EB), // 연한 회색 배경
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFF84E00), // 요청하신 주황색
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 2. 퍼센트(왼쪽) 및 페이지 정보(오른쪽)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 왼쪽: 퍼센트 (주황색)
                          Text(
                            '$progressPercent%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF84E00), // 요청하신 주황색
                            ),
                          ),
                          // 오른쪽: 현재/전체 페이지 (회색)
                          Text(
                            '${book.currentPage}/${book.totalPages}p',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 🔥 WISH 상태일 때만 프로필 스택 표시 (showProgress가 false일 때)
                    if (!showProgress) ...[
                      const SizedBox(height: 8), // 간격 띄우기
                      Align(
                        alignment: Alignment.centerRight, // 우측 정렬
                        child: _buildCelebrityStack(), // 스택 위젯 호출
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
