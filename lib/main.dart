import 'package:flutter/material.dart';
import 'package:whoreads/screens/celebrities/celebrities_page.dart';
import 'package:whoreads/screens/my_library/my_library_page.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const WhoReadsApp());
}

class WhoReadsApp extends StatelessWidget {
  const WhoReadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
