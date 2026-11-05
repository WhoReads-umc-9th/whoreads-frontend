import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WhoReadsBottomNav extends StatelessWidget {
  const WhoReadsBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _selectedColor = Color(0xFFF84E00);
  static const _iconColor = Color(0xFFCED0D4);

  Widget _libraryIcon(Color color) => SvgPicture.asset(
    'assets/images/basic/libarary.svg',
    width: 24,
    height: 24,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      side: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
    ),
    child: BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 0,
      selectedItemColor: _selectedColor,
      unselectedItemColor: const Color(0xFF757575),
      selectedIconTheme: const IconThemeData(color: _selectedColor, size: 24),
      unselectedIconTheme: const IconThemeData(color: _iconColor, size: 24),
      selectedFontSize: 12,
      unselectedFontSize: 12,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_rounded),
          label: '인물',
        ),
        BottomNavigationBarItem(
          icon: _libraryIcon(_iconColor),
          activeIcon: _libraryIcon(_selectedColor),
          label: '내 서재',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.topic_rounded),
          label: '주제',
        ),
      ],
    ),
  );
}
