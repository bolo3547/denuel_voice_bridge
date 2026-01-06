import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography for Denuel Voice Bridge
/// Friendly, readable, calming
class AppTextStyles {
  AppTextStyles._();

  // Headlines - Poppins (friendly, modern)
  static TextStyle headline1 = GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle headline2 = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle headline3 = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Body - Nunito (warm, approachable)
  static TextStyle bodyLarge = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.5,
  );

  // Reassuring message style (large, centered, calming)
  static TextStyle reassuring = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Button text
  static TextStyle button = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle buttonSecondary = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  );

  // Label/Caption
  static TextStyle label = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.3,
  );

  // Privacy notice style
  static TextStyle privacy = GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    fontStyle: FontStyle.italic,
  );
}
