import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:whoreads/screens/routine_setting.dart';
import 'package:whoreads/services/auth_service.dart';
import '../core/network/api_client.dart';
import '../services/notification_setting.dart';
import 'celebrities/celebrities_book_page.dart';
import 'dna_test/dnaTestDialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final NotificationSettingService _notificationSettingService = NotificationSettingService();
  bool isLoading = true;

  Map<String, dynamic> userInfo = {};
  List<dynamic> follows = [];
  Map<String, dynamic> dnaResult = {};
  List<dynamic> routineSettings = [];
  dynamic followSetting = {'id':-1,'is_enabled':true};

  final Color primaryOrange = const Color(0xFFFF6A00);
  final Color bgColor = const Color(0xFFF2F4F6);

  final List<String> _daysOfWeekEng = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
  final List<String> _daysOfWeekKor = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final results = await Future.wait([
        ApiClient.dio.get('/members/me'),
        ApiClient.dio.get('/members/me/follows'),
        ApiClient.dio.get('/dna/results'),
      ]);

      Map<String, dynamic>? settings = await _notificationSettingService.getAllSettings();

      if (settings == null) {
        await _notificationSettingService.addFollowSetting();
        settings = await _notificationSettingService.getAllSettings();
      }
      if (settings?['follow_setting'] != null) {
        followSetting = settings?['follow_setting'];
      }
      routineSettings = settings?['routine_settings'] ?? [];


      // 1. 내 정보 파싱
      if (results[0].statusCode == 200) {
        userInfo = AntiquityUserInfo(results[0].data['result']);
      }

      // 2. 팔로우 목록 파싱
      if (results[1].statusCode == 200) {
        follows = results[1].data['result'] ?? [];
      }

      // 3. 독서 DNA 파싱
      if (results[2].statusCode == 200) {
        dnaResult = results[2].data['result'] ?? {};
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

  Map<String, dynamic> AntiquityUserInfo(dynamic raw) {
    return raw ?? {};
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '00:00';
    try {
      final parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      String period = '오전';
      if (hour >= 12) {
        period = '오후';
        if (hour > 12) hour -= 12;
      } else if (hour == 0) {
        hour = 12;
      }

      return '$period $hour:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeStr;
    }
  }

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
    final headline = dnaResult['result_headline'] ?? '';
    final match = RegExp(r"'(.*?)'").firstMatch(headline);
    final extractedText = match?.group(1) ?? '';

    return Scaffold(
      backgroundColor: bgColor,
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

            /// 1. 프로필 상단 영역
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
                        final int? celebrityId = follow['id'] is int
                            ? follow['id'] as int
                            : int.tryParse('${follow['id']}');
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: celebrityId == null ? null : () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CelebritiesBookPage(celebrityId: celebrityId)));
                            },
                            customBorder: const CircleBorder(),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: follow['image_url'] != null && (follow['image_url'] as String).isNotEmpty
                                  ? NetworkImage(follow['image_url'] as String)
                                  : null,
                              child: follow['image_url'] == null || (follow['image_url'] as String?)?.isEmpty == true
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                          ),
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
                        value: followSetting['is_enabled'],
                        onChanged: (val) {
                          setState(() {
                            followSetting['is_enabled'] = val;
                          });

                          _notificationSettingService.updateSetting(
                              settingId: followSetting['id'],
                              notificationType: NotificationSettingType.follow,
                              isEnabled: val
                          );
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),

            /// 3. 독서 DNA 카드
            GestureDetector(
              onTap: () {
                showDialog(context: context, builder: (context) => const DnaTestDialog());
              },
              child: _buildCard(
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
                            text: "'${extractedText.isNotEmpty ? extractedText : '현실과 사회를 더 잘 이해하기 위해'}'",
                            style: TextStyle(color: primaryOrange, fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' 독서하는 사람입니다'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// 4. 독서 루틴 알림 카드
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('독서 루틴 알림', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.add, color: Colors.black87, size: 22),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RoutineSettingPage()),
                          ).then((_) {
                            setState(() { isLoading = true; });
                            _fetchAllData();
                          });
                        },
                      ),
                    ],
                  ),

                  routineSettings.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('설정된 독서 루틴 알림이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                      : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: routineSettings.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final routine = routineSettings[index];
                      final String formattedTime = _formatTime(routine['time']);
                      final bool isEnabled = routine['is_enabled'] ?? false;
                      final int routineId = routine['id'] ?? -1;

                      final List<String> targetDays = (routine['days'] as List<dynamic>? ?? []).cast<String>().toList();
                      final bool isEveryday = targetDays.length == 7;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoutineSettingPage(routine: routine),
                            ),
                          ).then((_) {
                            setState(() { isLoading = true; });
                            _fetchAllData();
                          });
                        },
                        child: Row(
                          children: [
                            Text(formattedTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
                            const Spacer(),

                            isEveryday
                                ? const Text('매일', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500))
                                : RichText(
                              text: TextSpan(
                                children: List.generate(7, (dayIdx) {
                                  final engDay = _daysOfWeekEng[dayIdx];
                                  final korDay = _daysOfWeekKor[dayIdx];
                                  final isHighlighted = targetDays.contains(engDay);

                                  return TextSpan(
                                    text: '$korDay ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                                      color: isHighlighted ? primaryOrange : Colors.grey,
                                    ),
                                  );
                                }),
                              ),
                            ),
                            CupertinoSwitch(
                              activeColor: primaryOrange,
                              value: isEnabled,
                              onChanged: (val) {
                                setState(() {
                                  routine['is_enabled'] = val;
                                });

                                _notificationSettingService.updateSetting(
                                    settingId: routineId,
                                    notificationType: NotificationSettingType.routine,
                                    rawTimeStr: routine['time']?.toString().substring(0, 5),
                                    rawDayStr: routine['days'].cast<String>().toList(),
                                    isEnabled: val
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
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

            /// 6. 로그아웃 카드
            _buildCard(
              child: InkWell(
                onTap: () async {
                  await _authService.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route)=> false);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Text('로그아웃', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20)
          ],
        ),
      ),
    );
  }

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