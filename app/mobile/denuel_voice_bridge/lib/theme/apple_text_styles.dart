import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'apple_colors.dart';

/// Apple-inspired typography for Denuel Voice Bridge
/// 
/// Design Philosophy:
/// - SF Pro-style clarity (using Inter as closest Google Font)
/// - Large, readable text for accessibility
/// - Clear hierarchy through weight, not color
/// - Generous line height for calm reading
/// - Text-led design - words carry the interface
class AppleTextStyles {
  AppleTextStyles._();

  // Large Title - iOS large title style
  static TextStyle largeTitle = GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    color: AppleColors.label,
    height: 1.2,
  );

  // Title 1 - Primary headings
  static TextStyle title1 = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.36,
    color: AppleColors.label,
    height: 1.2,
  );

  // Title 2 - Secondary headings
  static TextStyle title2 = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.35,
    color: AppleColors.label,
    height: 1.3,
  );

  // Title 3 - Tertiary headings
  static TextStyle title3 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.38,
    color: AppleColors.label,
    height: 1.3,
  );

  // Headline - Emphasized body text
  static TextStyle headline = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    color: AppleColors.label,
    height: 1.4,
  );

  // Body - Primary content
  static TextStyle body = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    color: AppleColors.label,
    height: 1.5,
  );

  // Callout - Slightly smaller body
  static TextStyle callout = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    color: AppleColors.label,
    height: 1.4,
  );

  // Subheadline - Supporting text
  static TextStyle subheadline = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    color: AppleColors.secondaryLabel,
    height: 1.4,
  );

  // Footnote - Small details
  static TextStyle footnote = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    color: AppleColors.tertiaryLabel,
    height: 1.4,
  );

  // Caption 1 - Labels
  static TextStyle caption1 = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppleColors.tertiaryLabel,
    height: 1.3,
  );

  // Caption 2 - Smallest text
  static TextStyle caption2 = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
    color: AppleColors.tertiaryLabel,
    height: 1.2,
  );

  // For reassuring messages - centered, warm
  static TextStyle reassurance = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.35,
    color: AppleColors.label,
    height: 1.4,
  );

  // Button text
  static TextStyle button = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    color: Colors.white,
    height: 1.2,
  );

  // Secondary button text
  static TextStyle buttonSecondary = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    color: AppleColors.accent,
    height: 1.2,
  );
}
