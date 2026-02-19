import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/token_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;

  // API 데이터 저장 변수
  Map<String, dynamic> userInfo = {};
  List<dynamic> follows = [];
  Map<String, dynamic> dnaResult = {};

  // 스위치 상태 관리
  bool isLibraryUpdateOn = true;
  bool isRoutineMorningOn = false;
  bool isRoutineNightOn = true;

  final Color primaryOrange = const Color(0xFFFF6A00);
  final Color bgColor = const Color(0xFFF2F4F6); // 배경 회색

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  // 🌟 3개의 API를 동시에 호출하여 데이터 가져오기
  Future<void> _fetchAllData() async {
    final token = await TokenStorage.getAccessToken();
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      final meUrl = Uri.parse('http://43.201.122.162/api/members/me');
      final followsUrl = Uri.parse('http://43.201.122.162/api/members/me/follows');
      final dnaUrl = Uri.parse('http://43.201.122.162/api/dna/results');

      final results = await Future.wait([
        http.get(meUrl, headers: headers),
        http.get(followsUrl, headers: headers),
        http.get(dnaUrl, headers: headers),
      ]);

      // 1. 내 정보 파싱
      if (results[0].statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(results[0].bodyBytes));
        userInfo = decoded['result'] ?? {};
      }

      // 2. 팔로우 목록 파싱
      if (results[1].statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(results[1].bodyBytes));
        follows = decoded['result'] ?? [];
      }

      // 3. 독서 DNA 파싱
      if (results[2].statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(results[2].bodyBytes));
        dnaResult = decoded['result'] ?? {};
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Profile API Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 데이터 변환 헬퍼 함수 (영어 -> 한글)
  String _getGender(String? gender) {
    if (gender == 'MALE') return '남자';
    if (gender == 'FEMALE') return '여자';
    return '-';
  }

  String _getAge(String? age) {
    switch (age) {
      case 'TEENAGERS': return '10대';
      case 'TWENTIES': return '20대';
      case 'THIRTIES': return '30대';
      case 'FORTIES': return '40대';
      case 'FIFTIES_PLUS': return '50대 이상';
      default: return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryOrange)),
      );
    }

    final String nickname = userInfo['nickname'] ?? '이름 없음';

    return Scaffold(
      backgroundColor: bgColor, // 전체 배경색 지정
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '프로필',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            /// 1. 프로필 상단 영역 (아바타 & 닉네임)
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: const Icon(Icons.menu_book, size: 40, color: Color(0xFFFF6A00)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nickname,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            /// 2. 팔로우 목록 & 서재 업데이트 알림 카드
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_add_outlined, color: Colors.black54, size: 20),
                      const SizedBox(width: 8),
                      const Text('팔로우 목록', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 팔로우 아바타 리스트
                  follows.isEmpty
                      ? const Text('팔로우한 유명인이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13))
                      : SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: follows.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final follow = follows[index];
                        return CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: follow['image_url'] != null ? NetworkImage(follow['image_url']) : null,
                          child: follow['image_url'] == null ? const Icon(Icons.person, color: Colors.grey) : null,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('서재 업데이트 알림', style: TextStyle(fontSize: 15, color: Colors.black87)),
                      const Spacer(),
                      CupertinoSwitch(
                        activeColor: primaryOrange,
                        value: isLibraryUpdateOn,
                        onChanged: (val) => setState(() => isLibraryUpdateOn = val),
                      ),
                    ],
                  )
                ],
              ),
            ),

            /// 3. 독서 DNA 카드
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_mosaic_outlined, color: Colors.black54, size: 20),
                      const SizedBox(width: 8),
                      const Text('독서 DNA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  dnaResult.isEmpty
                      ? const Text('진행한 독서 DNA 테스트가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 14))
                      : RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                      children: [
                        TextSpan(text: '$nickname님은 '),
                        TextSpan(
                          text: "' ${dnaResult['result_hea_line'] ?? '현실과 사회를 더 잘 이해하기 위해'} '",
                          style: TextStyle(color: primaryOrange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// 4. 독서 루틴 알림 카드 (정적 UI)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('독서 루틴 알림', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const Spacer(),
                      const Icon(Icons.add, color: Colors.black54, size: 22),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 첫 번째 알람
                  Row(
                    children: [
                      const Text('오전 8:00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Text('매일', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(width: 12),
                      CupertinoSwitch(
                        activeColor: primaryOrange,
                        value: isRoutineMorningOn,
                        onChanged: (val) => setState(() => isRoutineMorningOn = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 두 번째 알람
                  Row(
                    children: [
                      const Text('오후 10:00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      RichText(
                        text: TextSpan(
                            style: const TextStyle(fontSize: 13),
                            children: [
                              TextSpan(text: '일 월 화 수 ', style: TextStyle(color: primaryOrange, fontWeight: FontWeight.bold)),
                              const TextSpan(text: '목 금 토', style: TextStyle(color: Colors.grey)),
                            ]
                        ),
                      ),
                      const SizedBox(width: 12),
                      CupertinoSwitch(
                        activeColor: primaryOrange,
                        value: isRoutineNightOn,
                        onChanged: (val) => setState(() => isRoutineNightOn = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// 5. 계정 관리 카드
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('계정 관리', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  _buildAccountRow('닉네임', nickname),
                  _buildAccountRow('성별', _getGender(userInfo['gender'])),
                  _buildAccountRow('연령', _getAge(userInfo['age_group'])),

                  // API에 아이디/이메일이 없다면 UI 사진대로 하드코딩 표시
                  _buildAccountRow('아이디', userInfo['login_id'] ?? 'yhj8081'),
                  _buildAccountRow('이메일', userInfo['email'] ?? 'yhj8081@naver.com'),

                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('비밀번호 재설정', style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
                      Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 흰색 둥근 카드 컨테이너 빌더
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  // 계정 관리 내부 Row 위젯
  Widget _buildAccountRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}