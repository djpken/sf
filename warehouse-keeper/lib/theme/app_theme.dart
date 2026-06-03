import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF531721);
  static const Color primaryDark = Color(0xFF3B1017);
  static const Color accent = Color(0xFFF29600);
  static const Color accentSoft = Color(0xFFFFEDC2);
  static const Color surface = Color(0xFFFFF4DC);
  static const Color surfaceAlt = Color(0xFFFFFAF2);
  static const Color cardBg = Color(0xFFFFFCF7);
  static const Color border = Color(0xFFE8D9C4);
  static const Color textPrimary = Color(0xFF231815);
  static const Color textSecondary = Color(0xFF717071);
  static const Color success = Color(0xFF0E8F68);
  static const Color warning = Color(0xFFD47800);
  static const Color error = Color(0xFFC23B3B);

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration iconTileDecoration(Color color) => BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      );

  static Widget brandMark({double size = 44}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accentSoft,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: Icon(
          Icons.home_work_outlined,
          color: primary,
          size: size * 0.58,
        ),
      );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          surface: surface,
          error: error,
        ),
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: accentSoft,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: accentSoft,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: accentSoft),
        ),
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 0,
          shadowColor: primary.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: accentSoft,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: accentSoft,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: accent, width: 2),
          ),
          filled: true,
          fillColor: cardBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
