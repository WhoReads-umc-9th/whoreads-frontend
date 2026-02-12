import 'package:flutter/material.dart';
import 'tabs/saved_tab.dart';
import 'tabs/reading_tab.dart';
import 'tabs/finished_tab.dart';
import 'widgets/dna_card.dart';
import 'widgets/reading_summary_card.dart';

class MyLibraryPage extends StatelessWidget {
  const MyLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,

        /// ===== AppBar =====
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Whoreads',
            style: TextStyle(
              color: Color(0xFFFF6A00),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: const [
            Icon(Icons.timer_outlined, color: Colors.black),
            SizedBox(width: 16),
            Icon(Icons.notifications_none, color: Colors.black),
            SizedBox(width: 16),
            Icon(Icons.person_outline, color: Colors.black),
            SizedBox(width: 16),
          ],
        ),

        /// ===== Body =====
        body: Column(
          children: [
            const SizedBox(height: 12),

            /// 독서 DNA 카드
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: DnaCard(),
            ),

            const SizedBox(height: 16),

            /// 독서 기록 요약 카드
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ReadingSummaryCard(
                username: '하람',
                accessToken: 'yourJwtToken',
              ),
            ),

            const SizedBox(height: 16),

            /// TabBar
            const TabBar(
              labelColor: Colors.black,
              indicatorColor: Color(0xFFFF6A00),
              tabs: [
                Tab(text: '담아둠'),
                Tab(text: '읽는 중'),
                Tab(text: '다 읽음'),
              ],
            ),

            /// TabBarView
            const Expanded(
              child: TabBarView(
                children: [
                  SavedTab(),
                  ReadingTab(books: [],),
                  FinishedTab(books: [],),
                ],
              ),
            ),
          ],
        ),

        /// BottomNavigationBar
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 0,
          selectedItemColor: Colors.orange,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: '내 서재',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: '인물',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.topic),
              label: '주제',
            ),
          ],
        ),
      ),
    );
  }
}
