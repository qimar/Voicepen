import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Warm Editorial Typographic System for VoicePen.
/// Incorporates calibrated leading and kerning ratios to evoke literary typesetting.
abstract class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 40 / 32,
        letterSpacing: -0.02 * 32,
        color: AppColors.inkPrimary,
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 36 / 28,
        letterSpacing: -0.015 * 28,
        color: AppColors.inkPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.01 * 24,
        color: AppColors.inkPrimary,
      );

  static TextStyle get headlineSmall => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 28 / 20,
        letterSpacing: -0.005 * 20,
        color: AppColors.inkPrimary,
      );

  // Calibrated for long-form reading on OLED displays (~1.58x leading)
  static TextStyle get bodyXLarge => GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w400,
        height: 30 / 19,
        letterSpacing: -0.005 * 19,
        color: AppColors.inkPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 26 / 16,
        letterSpacing: 0,
        color: AppColors.inkPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 22 / 14,
        letterSpacing: 0,
        color: AppColors.inkMuted,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.01 * 14,
        color: AppColors.inkPrimary,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.02 * 12,
        color: AppColors.inkMuted,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.04 * 11,
        color: AppColors.inkMuted,
      );
}
