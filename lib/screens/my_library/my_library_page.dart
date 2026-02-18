import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/token_storage.dart';
import '../auth/SignupOverlayDialog.dart';
import '../celebrities/celebrities_page.dart';
import '../dna_test/dnaTestDialog.dart';
import 'tabs/saved_tab.dart';
import 'tabs/reading_tab.dart';
import 'tabs/finished_tab.dart';
import 'widgets/dna_card.dart';
import 'widgets/reading_summary_card.dart';

class MyLibraryPage extends StatefulWidget {
  final String? email;
  final String? loginId;
  final String? password;

  const MyLibraryPage({
    super.key,
    this.email,
    this.loginId,
    this.password,
  });

  @override
  State<MyLibraryPage> createState() => _MyLibraryPageState();
}

class _MyLibraryPageState extends State<MyLibraryPage> {
  String? accessToken;
  String? nickname;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _initialize();

    if (widget.email != null &&
        widget.loginId != null &&
        widget.password != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSignupDialog();
      });
    }
  }

  void _showSignupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) {
        return SignupOverlayDialog(
          email: widget.email!,
          loginId: widget.loginId!,
          password: widget.password!,
        );
      },
    );
  }

  void _showDnaTestDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // 바깥 영역 클릭 시 닫힘
      barrierColor: Colors.black.withOpacity(0.5), // 뒷배경 어둡게
      builder: (context) {
        return const DnaTestDialog();
      },
    );
  }

  Future<void> _initialize() async {
    final token = await TokenStorage.getAccessToken();

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    accessToken = token;
    await _fetchMyInfo();
  }

  Future<void> _fetchMyInfo() async {
    final response = await http.get(
      Uri.parse('http://43.201.122.162/api/members/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['result'];

      setState(() {
        nickname = result['nickname'];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (accessToken == null) {
      return const Scaffold(
        body: Center(
          child: Text('토큰이 없습니다. 다시 로그인해주세요.'),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,

        /// ===== AppBar =====
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          title: SvgPicture.asset(
            'assets/images/logo.svg',
            height: 18, // 높이를 지정하면 비율에 맞춰 너비가 자동 조절됩니다.
            // 만약 로고 색상을 강제로 주황색으로 바꿔야 한다면 아래 주석 해제
            // colorFilter: const ColorFilter.mode(Color(0xFFFF6A00), BlendMode.srcIn),
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
            /// 독서 DNA 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint("DNA Card Clicked!"); // 이제 무조건 뜹니다!
                  _showDnaTestDialog();
                },
                child: const AbsorbPointer(
                  child: DnaCard(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 독서 기록 요약 카드 (nickname 적용)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReadingSummaryCard(
                username: nickname ?? '사용자',
                accessToken: accessToken!,
              ),
            ),

            const SizedBox(height: 16),

            /// TabBar
            const TabBar(
              labelColor: Colors.black,
              indicatorColor: Color(0xFFFF6A00),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: '담아둠'),
                Tab(text: '읽는 중'),
                Tab(text: '다 읽음'),
              ],
            ),

            /// TabBarView
            Expanded(
              child: TabBarView(
                children: [
                  SavedTab(accessToken: accessToken!),
                  ReadingTab(accessToken: accessToken!, books: []),
                  FinishedTab(accessToken: accessToken!, books: []),
                ],
              ),
            ),
          ],
        ),

        /// ===== BottomNavigationBar =====
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 1,
          selectedItemColor: Colors.orange,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CelebritiesPage(),
                ),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: '인물',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: '내 서재',
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
