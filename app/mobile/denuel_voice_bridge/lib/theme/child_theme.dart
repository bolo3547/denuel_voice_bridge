import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Child Mode Theme - Friendly, playful, fear-free design
class ChildTheme {
  // Primary colors - Soft, cheerful palette
  static const Color primary = Color(0xFF6366F1); // Indigo 500
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo 600

  // Accent colors
  static const Color accent = Color(0xFFF472B6); // Pink 400
  static const Color accentLight = Color(0xFFFBCFE8); // Pink 200
  
  // Background colors - Soft, warm
  static const Color background = Color(0xFFFFFBEB); // Amber 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFEF3C7); // Amber 100

  // Fun gradient backgrounds
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7), Color(0xFFFDE68A)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFF6366F1), Color(0xFFA78BFA)],
  );

  // Text colors
  static const Color textPrimary = Color(0xFF1E1B4B); // Indigo 950
  static const Color textSecondary = Color(0xFF4338CA); // Indigo 700
  static const Color textTertiary = Color(0xFF6366F1); // Indigo 500

  // Fun status colors
  static const Color success = Color(0xFF34D399); // Emerald 400
  static const Color warning = Color(0xFFFBBF24); // Amber 400
  static const Color error = Color(0xFFF87171); // Red 400
  static const Color info = Color(0xFF60A5FA); // Blue 400

  // Reward colors
  static const Color gold = Color(0xFFFBBF24);
  static const Color silver = Color(0xFFA8A29E);
  static const Color bronze = Color(0xFFD97706);
  static const Color star = Color(0xFFFCD34D);

  // Border colors
  static const Color border = Color(0xFFE0E7FF); // Indigo 100
  static const Color borderFocused = primary;

  // Card shadows - softer for children
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withOpacity(0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get cardShadowElevated => [
        BoxShadow(
          color: primary.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // Border radius - more rounded for friendly feel
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusXL = 32;
  static const double radiusFull = 100;

  // Spacing - larger for easy touch targets
  static const double spacingXS = 8;
  static const double spacingS = 12;
  static const double spacingM = 20;
  static const double spacingL = 28;
  static const double spacingXL = 40;
  static const double spacingXXL = 56;

  // Touch target minimum (44px as per accessibility guidelines)
  static const double minTouchTarget = 48;

  // Text styles - rounded, friendly fonts
  static TextStyle get headlineLarge => GoogleFonts.nunito(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.2,
      );

  static TextStyle get headlineMedium => GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
      );

  static TextStyle get headlineSmall => GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
      );

  static TextStyle get titleLarge => GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.4,
      );

  static TextStyle get titleMedium => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.4,
      );

  static TextStyle get bodyLarge => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textTertiary,
        height: 1.5,
      );

  static TextStyle get buttonText => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.2,
      );

  static TextStyle get gameScore => GoogleFonts.fredoka(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: gold,
        height: 1.1,
      );

  static TextStyle get avatarSpeech => GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.4,
      );

  // Avatar expressions
  static const Map<String, String> avatarEmojis = {
    'happy': '😊',
    'excited': '🤩',
    'encouraging': '💪',
    'thinking': '🤔',
    'celebrating': '🎉',
    'calm': '😌',
    'listening': '👂',
    'speaking': '🗣️',
  };

  // Theme data
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.light(
          primary: primary,
          primaryContainer: primaryLight,
          secondary: accent,
          secondaryContainer: accentLight,
          surface: surface,
          background: background,
          error: error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textPrimary,
          onBackground: textPrimary,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: titleLarge,
        ),
        cardTheme: CardTheme(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: primary.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            minimumSize: const Size(minTouchTarget, minTouchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLarge),
            ),
            textStyle: buttonText,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            minimumSize: const Size(minTouchTarget, minTouchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLarge),
            ),
            textStyle: buttonText.copyWith(color: primary),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusFull),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textTertiary.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: bodySmall.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: bodySmall,
        ),
      );

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration celebrationDuration = Duration(seconds: 3);
}
