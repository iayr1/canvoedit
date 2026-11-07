import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF0E0F13);
  static const surface = Color(0xFF181A20);
  static const surfaceHigh = Color(0xFF242731);
  static const line = Color(0xFF32353F);
  static const coral = Color(0xFFFF5C39);
  static const violet = Color(0xFF7C5CFF);
  static const muted = Color(0xFF9CA0AD);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.coral,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.coral,
    secondary: AppColors.violet,
    surface: AppColors.surface,
    onPrimary: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
      inactiveTrackColor: AppColors.line,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
