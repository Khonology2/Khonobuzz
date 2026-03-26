import 'package:flutter/material.dart';

/// Light and dark [ThemeData] for [MaterialApp].
abstract final class AppThemes {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Poppins',
        primaryColor: const Color(0xFFC10D00),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC10D00),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          bodyMedium: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          titleLarge: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
      );

  static ThemeData get light => ThemeData(
        fontFamily: 'Poppins',
        primaryColor: const Color(0xFFC10D00),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC10D00),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Poppins'),
          bodyMedium:
              TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Poppins'),
          titleLarge:
              TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Poppins'),
        ),
      );
}
