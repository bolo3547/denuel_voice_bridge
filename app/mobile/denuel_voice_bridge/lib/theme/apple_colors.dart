import 'package:flutter/material.dart';

/// Apple-inspired color palette for Denuel Voice Bridge
/// 
/// Design Philosophy:
/// - Neutral, calming backgrounds (Apple's signature off-white)
/// - Subtle accents that don't demand attention
/// - No harsh colors - everything feels quiet and safe
/// - Inspired by iOS Settings, Voice Memos, Health app
class AppleColors {
  AppleColors._();

  // Backgrounds - Apple's signature layered grays
  static const Color background = Color(0xFFF5F5F7);        // Apple off-white
  static const Color secondaryBackground = Color(0xFFFFFFFF); // Pure white cards
  static const Color tertiaryBackground = Color(0xFFF2F2F7); // Grouped background

  // Text - Apple's text hierarchy
  static const Color label = Color(0xFF000000);              // Primary label
  static const Color secondaryLabel = Color(0xFF3C3C43);     // 60% opacity feel
  static const Color tertiaryLabel = Color(0xFF8E8E93);      // Placeholder/hint
  static const Color quaternaryLabel = Color(0xFFC7C7CC);    // Disabled

  // Accent - Subtle, trustworthy blue (not iOS blue, softer)
  static const Color accent = Color(0xFF5E5CE6);             // Soft indigo
  static const Color accentLight = Color(0xFFE8E7FA);        // Tinted background
  
  // System colors - gentle versions
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemGray5 = Color(0xFFE5E5EA);
  static const Color systemGray6 = Color(0xFFF2F2F7);

  // Semantic - gentle, non-alarming
  static const Color success = Color(0xFF34C759);            // Apple green (subtle use)
  static const Color gentle = Color(0xFF5AC8FA);             // Soft cyan
  static const Color destructive = Color(0xFFFF3B30);        // Apple red (use sparingly)
  
  // Listening state - warm, not alarming
  static const Color listening = Color(0xFF5E5CE6);          // Same as accent

  // Separators
  static const Color separator = Color(0xFFC6C6C8);
  static const Color opaqueSeparator = Color(0xFFE5E5EA);

  // Fill colors for buttons
  static const Color systemFill = Color(0xFF787880);         // 20% opacity
  static const Color secondaryFill = Color(0xFF787880);      // 16% opacity
  static const Color tertiaryFill = Color(0xFF767680);       // 12% opacity
}
