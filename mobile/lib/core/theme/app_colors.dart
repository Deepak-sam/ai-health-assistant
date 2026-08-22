import 'package:flutter/material.dart';

/// Calm, minimal, ChatGPT-style palette. Deliberately avoids the "clinical
/// hospital" look (bright reds/greens as status colors, harsh blues) and any
/// gamification color language (badges, streak-fire colors, etc).
abstract class AppColors {
  // Light theme
  static const Color lightBackground = Color(0xFFFAFAF8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF2F1EC);
  static const Color lightBorder = Color(0xFFE6E4DD);
  static const Color lightTextPrimary = Color(0xFF1F1E1C);
  static const Color lightTextSecondary = Color(0xFF6B6A65);
  static const Color lightAccent = Color(0xFF3F6B5C); // muted sage green
  static const Color lightAccentMuted = Color(0xFFDCE7E2);
  static const Color lightBubbleUser = Color(0xFFEFECE4);
  static const Color lightBubbleAssistant = Color(0xFFFFFFFF);

  // Dark theme
  static const Color darkBackground = Color(0xFF17181A);
  static const Color darkSurface = Color(0xFF1F2123);
  static const Color darkSurfaceMuted = Color(0xFF26282B);
  static const Color darkBorder = Color(0xFF33353A);
  static const Color darkTextPrimary = Color(0xFFEDEDEC);
  static const Color darkTextSecondary = Color(0xFFA0A09A);
  static const Color darkAccent = Color(0xFF7FB6A0); // muted sage green
  static const Color darkAccentMuted = Color(0xFF243430);
  static const Color darkBubbleUser = Color(0xFF2A2C2F);
  static const Color darkBubbleAssistant = Color(0xFF1F2123);

  // Shared status colors — used sparingly, no gamified badges/streaks.
  static const Color warning = Color(0xFFB8863A);
  static const Color danger = Color(0xFFB1503F);
  static const Color success = Color(0xFF4C8067);
}
