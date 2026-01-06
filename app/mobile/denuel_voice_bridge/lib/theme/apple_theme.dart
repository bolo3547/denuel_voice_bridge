import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apple_colors.dart';
import 'apple_text_styles.dart';

/// Apple-inspired theme for Denuel Voice Bridge
/// 
/// Creates the complete Material theme that mimics iOS design language
class AppleTheme {
  AppleTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppleColors.background,
      
      colorScheme: ColorScheme.light(
        primary: AppleColors.accent,
        secondary: AppleColors.accent,
        surface: AppleColors.secondaryBackground,
        background: AppleColors.background,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppleColors.label,
        onBackground: AppleColors.label,
      ),

      // App bar - minimal, blends with background
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppleColors.background,
        foregroundColor: AppleColors.label,
        centerTitle: true,
        titleTextStyle: AppleTextStyles.headline,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Cards - subtle shadow, rounded corners
      cardTheme: CardTheme(
        elevation: 0,
        color: AppleColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.zero,
      ),

      // Buttons - pill shaped
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppleColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppleTextStyles.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppleColors.accent,
          textStyle: AppleTextStyles.buttonSecondary,
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppleColors.tertiaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: AppleColors.opaqueSeparator,
        thickness: 0.5,
        space: 0,
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppleColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: AppleColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
