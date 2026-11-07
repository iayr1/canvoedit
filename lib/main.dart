import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const CanvoEditApp());
}

class CanvoEditApp extends StatelessWidget {
  const CanvoEditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canvo Edit',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
