import 'package:flutter/material.dart';

/// FollowBoost visual identity: dark background, violet -> pink gradient
/// accents, rounded cards, white text with muted secondary text.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF17171F);
  static const Color surfaceLight = Color(0xFF21212C);
  static const Color violet = Color(0xFF7C3AED);
  static const Color pink = Color(0xFFEC4899);
  static const Color gold = Color(0xFFF59E0B);
  static const Color green = Color(0xFF10B981);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF9AA3B2);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [violet, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double cardRadius = 20;

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: violet,
          secondary: pink,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: violet, width: 1.5),
          ),
          hintStyle: const TextStyle(color: textMuted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: violet,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: pink,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: surfaceLight,
          contentTextStyle: TextStyle(color: textPrimary),
          behavior: SnackBarBehavior.floating,
        ),
      );

  /// Avatar background color from a stored hex string like '#7C3AED'.
  static Color avatarColor(String hex) {
    try {
      final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
      return Color(0xFF000000 | value);
    } catch (_) {
      return violet;
    }
  }

  /// Fade + slide page transition used across the app.
  static Route<T> fadeSlideRoute<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      );
}
