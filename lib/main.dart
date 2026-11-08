import 'dart:async';

import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'core/crash_log.dart';
import 'features/home/home_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    CrashLog.install();
    runApp(const CanvoEditApp());
  }, CrashLog.record);
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
