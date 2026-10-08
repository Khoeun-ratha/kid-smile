import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widgets/responsive.dart';

class AppTheme {
  static const Color background = Color(0xFFFFF8E7);
  static const Color primary = Color(0xFFFF6F61);
  static const Color correct = Color(0xFF4CAF50);
  static const Color wrong = Color(0xFFE53935);

  static ThemeData get theme => themeFor(ScreenClass.phone);

  /// Tests have no network to download the font from, so they switch it
  /// off; layout metrics are what they check, not the typeface.
  @visibleForTesting
  static bool useGoogleFonts = true;

  // Built once per class: the app-level builder asks for a theme on every
  // MediaQuery change (rotation, keyboard), and GoogleFonts text themes
  // aren't free to build.
  static final Map<ScreenClass, ThemeData> _cache = {};

  /// Theme tuned to the device: a slimmer app bar when height is scarce
  /// (phone sideways), and larger text throughout on tablets/desktop.
  static ThemeData themeFor(ScreenClass screen) =>
      _cache.putIfAbsent(screen, () => _build(screen));

  static ThemeData _build(ScreenClass screen) {
    final (toolbarHeight, titleSize, iconSize, fontScale) = switch (screen) {
      ScreenClass.short => (56.0, 24.0, 26.0, 1.0),
      ScreenClass.phone => (72.0, 30.0, 30.0, 1.0),
      ScreenClass.large => (84.0, 36.0, 34.0, 1.15),
    };

    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primary,
      // Transparent so the app-wide KidBackground shows through.
      scaffoldBackgroundColor: Colors.transparent,
    );
    // ThemeData's own text theme carries colors but no sizes yet (Flutter
    // fills those in later), so merge in the Material sizes first — scaling
    // needs concrete sizes to multiply.
    final sized = Typography.material2021().englishLike.merge(base.textTheme);
    final textTheme =
        (useGoogleFonts ? GoogleFonts.baloo2TextTheme(sized) : sized).apply(
          fontSizeFactor: fontScale,
        );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: Colors.brown.shade800,
        // Big, chunky titles that young kids can read at a glance; the bar
        // is taller to fit them (and Khmer's tall stacked glyphs).
        toolbarHeight: toolbarHeight,
        iconTheme: IconThemeData(color: Colors.brown.shade800, size: iconSize),
        actionsIconTheme: IconThemeData(
          color: Colors.brown.shade800,
          size: iconSize,
        ),
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          fontSize: titleSize,
          fontWeight: FontWeight.w800,
          color: Colors.brown.shade800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static Color fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
