import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SakannaApp());
}

class SakannaApp extends StatelessWidget {
  const SakannaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سكنّا',
      debugShowCheckedModeBanner: false,
      theme: buildSakannaTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
