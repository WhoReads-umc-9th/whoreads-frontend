import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WhoReadsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WhoReadsAppBar({super.key, required this.title, this.actions});

  final Widget title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
    title: title,
    actions: actions,
  );
}
