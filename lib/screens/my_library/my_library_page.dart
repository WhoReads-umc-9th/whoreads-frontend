import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:whoreads/screens/notification_screen.dart';
import 'package:whoreads/screens/timer/timer_default_screen.dart';
import 'package:whoreads/screens/topics/topics_page.dart';
import '../../core/auth/token_storage.dart';
import '../auth/SignupOverlayDialog.dart';
import '../celebrities/celebrities_page.dart';
import '../dna_test/dnaTestDialog.dart';
import '../profile.dart';
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
  bool hasDnaResult = false;

  int _refreshKey = 0;

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

  Future<void> _showSignupDialog() async {
    final resultNickname = await showDialog<String>(
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

    if (resultNickname != null && resultNickname.isNotEmpty) {
      await _initialize();

      setState(() {
        nickname = resultNickname;
        _refreshKey++; // 값이 변경되면 Key가 바뀌면서 탭들이 새로 그려짐
      });
    }
  }

  void _showDnaTestDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
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

    // 🌟 내 정보와 DNA 결과를 동시에 불러옵니다.
    await Future.wait([
      _checkDnaResult(),
      _fetchMyInfo(),
    ]);
  }

  // 🌟 DNA 결과 확인 API 호출
  Future<void> _checkDnaResult() async {
    try {
      final response = await http.get(
        Uri.parse('http://43.201.122.162/api/dna/results'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      // 200 성공이면 결과를 가지고 있는 것으로 판단
      if (response.statusCode == 200) {
        setState(() {
          hasDnaResult = true;
        });
      } else {
        setState(() {
          hasDnaResult = false;
        });
      }
    } catch (e) {
      debugPrint('DNA 결과 조회 에러: $e');
      setState(() {
        hasDnaResult = false;
      });
    }
  }

  Future<void> _fetchMyInfo() async {
    try {
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
    } catch (e) {
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
          child: CircularProgressIndicator(color: Color(0xFFFF6A00)),
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
            height: 18,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.timer_outlined, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TimerPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
            const SizedBox(width: 16),
          ],
        ),

        /// ===== Body =====
        body: Column(
          children: [
            /// 🌟 DNA 결과가 없을 때만(!hasDnaResult) 독서 DNA 카드를 렌더링
            if (!hasDnaResult) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    debugPrint("DNA Card Clicked!");
                    _showDnaTestDialog();
                  },
                  child: const AbsorbPointer(
                    child: DnaCard(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                key: ValueKey(_refreshKey),
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
          selectedItemColor: const Color(0xFFF84E00),
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CelebritiesPage(),
                ),
              );
            }else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const TopicsPage(),
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
