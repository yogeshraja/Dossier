import 'package:flutter/material.dart';

class AppThemes {
  // --- Modern Sleek Dark Theme (Slate & Deep Indigo / Cyan) ---
  static ThemeData get darkTheme {
    const primaryColor = Color(0xFF6366F1); // Indigo 500
    const secondaryColor = Color(0xFF8B5CF6); // Violet 500
    const surfaceColor = Color(0xFF0F172A); // Slate 900
    const cardColor = Color(0xFF1E293B); // Slate 800
    const borderColor = Color(0xFF334155); // Slate 700
    const bgDark = Color(0xFF090D16); // Ultra-deep Slate 950

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        surface: surfaceColor,
        surfaceContainerHighest: Color(0xFF1E293B),
        onSurface: Color(0xFFF1F5F9),
        error: Color(0xFFEF4444),
        onError: Colors.white,
        outline: borderColor,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      dividerColor: borderColor,
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryColor.withValues(alpha: 0.2),
        secondarySelectedColor: primaryColor,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: IconThemeData(color: Color(0xFF818CF8)),
        unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8)),
        selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
    );
  }

  // --- Clean High-Contrast Light Theme (Slate 50 & Crisp Indigo) ---
  static ThemeData get lightTheme {
    const primaryColor = Color(0xFF4F46E5); // Indigo 600
    const secondaryColor = Color(0xFF7C3AED); // Violet 600
    const surfaceColor = Color(0xFFFFFFFF); // Pure white
    const cardColor = Color(0xFFFFFFFF);
    const borderColor = Color(0xFFE2E8F0); // Slate 200
    const bgLight = Color(0xFFF8FAFC); // Slate 50

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        surface: surfaceColor,
        surfaceContainerHighest: Color(0xFFF1F5F9),
        onSurface: Color(0xFF0F172A),
        error: Color(0xFFDC2626),
        onError: Colors.white,
        outline: borderColor,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      dividerColor: borderColor,
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: primaryColor.withValues(alpha: 0.15),
        secondarySelectedColor: primaryColor,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: IconThemeData(color: primaryColor),
        unselectedIconTheme: IconThemeData(color: Color(0xFF64748B)),
        selectedLabelTextStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
    );
  }
}
