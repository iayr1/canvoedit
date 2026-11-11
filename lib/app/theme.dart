import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF0B0A12);
  static const surface = Color(0xFF16141F);
  static const surfaceHigh = Color(0xFF221F2E);
  static const line = Color(0xFF34304A);
  static const coral = Color(0xFFFF5C39);
  static const pink = Color(0xFFFF3D8B);
  static const violet = Color(0xFF7C5CFF);
  static const cyan = Color(0xFF33D6E6);
  static const gold = Color(0xFFFFC857);
  static const muted = Color(0xFFA3A0B8);
}

class AppGradients {
  /// The brand sweep: used for primary buttons, selected rings and highlights.
  static const brand = LinearGradient(colors: [AppColors.coral, AppColors.pink, AppColors.violet], begin: Alignment.centerLeft, end: Alignment.centerRight);

  static const sunrise = LinearGradient(colors: [AppColors.gold, AppColors.coral, AppColors.pink]);
  static const ocean = LinearGradient(colors: [AppColors.cyan, AppColors.violet]);

  /// The rainbow ring drawn around the selected filter lens.
  static const ring = SweepGradient(colors: [AppColors.gold, AppColors.coral, AppColors.pink, AppColors.violet, AppColors.cyan, AppColors.gold]);

  /// Soft glow behind the app, giving the dark background some depth.
  static const backdrop = RadialGradient(center: Alignment(-.8, -1), radius: 1.4, colors: [Color(0xFF2A1640), AppColors.ink]);
}

/// The one typeface used across the app's own screens, bundled with the app.
const appFont = 'Poppins';

const _transitions = PageTransitionsTheme(
  builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()},
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.coral,
    brightness: Brightness.dark,
  ).copyWith(primary: AppColors.coral, secondary: AppColors.violet, surface: AppColors.surface, onPrimary: Colors.white);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return ThemeData(
    colorScheme: scheme,
    fontFamily: appFont,
    pageTransitionsTheme: _transitions,
    scaffoldBackgroundColor: AppColors.ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: appFont, fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -.2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: rounded, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.pink.withValues(alpha: .22),
      side: const BorderSide(color: Colors.transparent),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontFamily: appFont, fontSize: 12, fontWeight: FontWeight.w600),
      showCheckmark: false,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
      activeTrackColor: AppColors.pink,
      thumbColor: Colors.white,
      inactiveTrackColor: AppColors.line,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(fontFamily: appFont, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// A pill button filled with the brand gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.gradient = AppGradients.brand, this.compact = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(40),
          boxShadow: enabled ? [BoxShadow(color: AppColors.pink.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 6))] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22, vertical: compact ? 9 : 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: compact ? 18 : 20, color: Colors.white), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 14 : 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text painted with the brand gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, this.gradient = AppGradients.brand});
  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
    child: Text(text, style: style),
  );
}

/// Light palette for the browsing screens: home, templates and projects.
class LightColors {
  static const background = Color(0xFFF6F4FC);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B1530);
  static const muted = Color(0xFF6E6888);
  static const line = Color(0xFFE6E1F2);
  static const chip = Color(0xFFEFEBFA);
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
  ).copyWith(primary: AppColors.violet, secondary: AppColors.pink, surface: LightColors.card, onSurface: LightColors.text);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: appFont,
    pageTransitionsTheme: _transitions,
    scaffoldBackgroundColor: LightColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: LightColors.background,
      foregroundColor: LightColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: appFont, fontSize: 18, fontWeight: FontWeight.w800, color: LightColors.text, letterSpacing: -.3),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LightColors.card,
      indicatorColor: AppColors.violet.withValues(alpha: .12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: appFont,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: LightColors.text,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LightColors.card,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: LightColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}
