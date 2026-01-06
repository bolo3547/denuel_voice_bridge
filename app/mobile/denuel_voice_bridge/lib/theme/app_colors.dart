import 'package:flutter/material.dart';

/// Calm, safe color palette for Denuel Voice Bridge
/// No red error colors - everything feels safe and welcoming
class AppColors {
  AppColors._();

  // Primary - Soft Teal (calm, trustworthy)
  static const Color primary = Color(0xFF5B9A8B);
  static const Color primaryLight = Color(0xFF7EC8B8);
  static const Color primaryDark = Color(0xFF4A7C6F);

  // Secondary - Warm Blue (gentle, reassuring)
  static const Color secondary = Color(0xFF6B9AC4);
  static const Color secondaryLight = Color(0xFF9DBDD6);

  // Neutral - Warm tones (not cold gray)
  static const Color background = Color(0xFFFAF9F7);
  static const Color surface = Color(0xFFF8F6F4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text - Soft, readable
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textMuted = Color(0xFF9BA3A9);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Accent - Soft highlights
  static const Color accent = Color(0xFFE8D5B7);      // Warm beige
  static const Color accentLight = Color(0xFFF5EDE0);  // Light cream

  // States - Gentle, non-alarming
  static const Color listening = Color(0xFF7EC8B8);    // Soft green-teal
  static const Color success = Color(0xFF7EC8B8);      // Same gentle teal
  static const Color info = Color(0xFF9DBDD6);         // Soft blue
  
  // No red! Use soft amber for attention
  static const Color attention = Color(0xFFE8B86D);    // Warm amber

  // Gradients for buttons
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient calmGradient = LinearGradient(
    colors: [Color(0xFFF8F6F4), Color(0xFFFAF9F7)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
