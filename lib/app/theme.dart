import 'package:flutter/material.dart';

class AppThemes {
  // --- Modern Sleek Dark Theme ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: const Color(0xFF090D16),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1), // Indigo accent
        onPrimary: Colors.white,
        secondary: Color(0xFF8B5CF6), // Violet accent
        onSecondary: Colors.white,
        surface: Color(0xFF0F172A), // Slate 900
        onSurface: Color(0xFFF1F5F9),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      dividerColor: const Color(0xFF334155),
      dialogBackgroundColor: const Color(0xFF1E293B),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0F172A),
        selectedIconTheme: IconThemeData(color: Color(0xFF818CF8)),
        unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8)),
        selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }

  // --- Clean High-Contrast Light Theme ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Slate 100
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5), // Indigo 600
        onPrimary: Colors.white,
        secondary: Color(0xFF7C3AED), // Violet 600
        onSecondary: Colors.white,
        surface: Color(0xFFFFFFFF), // Pure white
        onSurface: Color(0xFF0F172A),
        error: Color(0xFFDC2626),
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      dividerColor: const Color(0xFFE2E8F0),
      dialogBackgroundColor: const Color(0xFFFFFFFF),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedIconTheme: IconThemeData(color: Color(0xFF4F46E5)),
        unselectedIconTheme: IconThemeData(color: Color(0xFF64748B)),
        selectedLabelTextStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF475569)),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
    );
  }
}
