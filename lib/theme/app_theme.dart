import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF0F4FD6);
  static const Color accent = Color(0xFF12A594);
  static const Color lightBg = Color(0xFFF3F6FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFD9E4F7);
  static const Color lightText = Color(0xFF1C2638);
  static const Color lightMuted = Color(0xFF657089);

  static const Color darkBg = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF101A2C);
  static const Color darkCardBorder = Color(0xFF253757);
  static const Color darkText = Color(0xFFEAF1FF);
  static const Color darkMuted = Color(0xFFA8B5CD);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: lightSurface,
        onSurface: lightText,
      ),
    );

    final textTheme = base.textTheme.apply(
      bodyColor: lightText,
      displayColor: lightText,
      fontFamilyFallback: const [
        'SUIT',
        'Pretendard',
        'Apple SD Gothic Neo',
        'Malgun Gothic',
        'Noto Sans CJK KR',
      ],
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: lightBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightText,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: lightText,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightCardBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: lightSurface,
        selectedItemColor: primary,
        unselectedItemColor: lightMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE9F0FD),
        selectedColor: const Color(0xFFD7E6FF),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: const Color(0xFF2D3B58),
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
        side: const BorderSide(color: Color(0xFFCFE0FC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFC4D8FB)),
          foregroundColor: const Color(0xFF27416F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: const Color(0xFF8B97B0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFC9D9F4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFC9D9F4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF93B7FF),
        secondary: Color(0xFF78E1D6),
        surface: darkSurface,
        onSurface: darkText,
      ),
    );

    final textTheme = base.textTheme.apply(
      bodyColor: darkText,
      displayColor: darkText,
      fontFamilyFallback: const [
        'SUIT',
        'Pretendard',
        'Apple SD Gothic Neo',
        'Malgun Gothic',
        'Noto Sans CJK KR',
      ],
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkText,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: darkText,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkCardBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: darkSurface,
        selectedItemColor: Color(0xFF9FC2FF),
        unselectedItemColor: darkMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF16263F),
        selectedColor: const Color(0xFF1F3660),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: const Color(0xFFBBD2FB),
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: const Color(0xFFCDE0FF),
          fontWeight: FontWeight.w800,
        ),
        side: const BorderSide(color: Color(0xFF2C4671)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A62BF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF37527E)),
          foregroundColor: const Color(0xFFC9DCFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: const Color(0xFF9BAAC4)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2B4166)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2B4166)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF9BBEFF), width: 1.4),
        ),
      ),
    );
  }
}
