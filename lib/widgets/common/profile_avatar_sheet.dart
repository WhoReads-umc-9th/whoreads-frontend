import 'package:flutter/material.dart';

/// 이미지 파일은 assets/images/profile_female_1.png ~ 6.png,
/// assets/images/profile_male_1.png ~ 6.png 위치에 추가합니다.
class ProfileAvatar {
  static String assetPath(String gender, int index) {
    final prefix = gender == 'MALE' ? 'male' : 'female';
    return 'assets/images/profile_${prefix}_${index + 1}.png';
  }

  static Widget image(String gender, int index, {double size = 100}) {
    return Image.asset(
      assetPath(gender, index),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: const Color(0xFFF5F5F5),
        alignment: Alignment.center,
        child: Icon(Icons.person_outline, color: Colors.grey, size: size * .55),
      ),
    );
  }
}

class ProfileAvatarSheet extends StatefulWidget {
  final String gender;
  final int initialIndex;
  const ProfileAvatarSheet({super.key, required this.gender, required this.initialIndex});

  @override
  State<ProfileAvatarSheet> createState() => _ProfileAvatarSheetState();
}

class _ProfileAvatarSheetState extends State<ProfileAvatarSheet> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) => InkWell(
                onTap: () => setState(() => selectedIndex = index),
                borderRadius: BorderRadius.circular(50),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedIndex == index
                            ? const Color(0xFFFF5722)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: ProfileAvatar.image(widget.gender, index, size: 68),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1B1F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('적용하기', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
