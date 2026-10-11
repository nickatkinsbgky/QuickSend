import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const QuickSendApp());
}

class QuickSendApp extends StatelessWidget {
  const QuickSendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickSend',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
