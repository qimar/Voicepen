import 'package:flutter/material.dart';

/// Warm Editorial Design System Color Palette for VoicePen.
/// Derived directly from Warm Editorial design tokens.
abstract class AppColors {
  // Base Canvas & Surfaces
  static const Color background = Color(0xFFFAF7F2);        // Warm cream canvas base
  static const Color surface = Color(0xFFFFFFFF);           // Pure white cards & dialog bodies
  static const Color surfaceElevated = Color(0xFFF4EFEB);   // Neutral tint for bottom sheets & docked players
  static const Color surfaceContainerLow = Color(0xFFF6F3EE);
  static const Color surfaceContainer = Color(0xFFF0EDE9);
  static const Color surfaceContainerHigh = Color(0xFFEBE8E3);
  static const Color surfaceContainerHighest = Color(0xFFE5E2DD);

  // Terracotta Brand Pigments (Primary System)
  static const Color primary = Color(0xFFC25E3E);           // Warm terracotta accent (FAB, primary buttons, record)
  static const Color primaryPressed = Color(0xFFA94B2E);    // Burnished terracotta (pressed / hover states)
  static const Color primaryTint = Color(0xFFF5EAE4);       // Soft warm low-contrast wash (active chips, waveforms)
  static const Color primaryDark = Color(0xFF7E2C10);
  static const Color primaryLight = Color(0xFFFFDBD0);
  static const Color peachTint = Color(0xFFFEE8E1);         // Pro badge / highlight tint
  static const Color highlightPeach = Color(0xFFFFEBE4);    // Syllable highlight
  static const Color playingBg = Color(0xFFFBF6F2);         // Active verbatim chunk

  // Secondary Accents
  static const Color secondary = Color(0xFF9D4226);
  static const Color secondaryContainer = Color(0xFFFE8C6A);

  // Ink Typography Hierarchy
  static const Color inkPrimary = Color(0xFF1C1917);        // Deep espresso ink (headlines, note titles, body)
  static const Color inkMuted = Color(0xFF57534E);          // Warm charcoal (metadata, subtitles, captions)
  static const Color inkSubtle = Color(0xFF89726B);         // Outline / tertiary muted text
  static const Color onPrimary = Color(0xFFFFFFFF);         // Pure white text on primary terracotta

  // Structural Hairline Borders
  static const Color borderSubtle = Color(0xFFE7E0D8);      // Delicate warm parchment hairline (1px)
  static const Color borderFocus = Color(0xFFC25E3E);

  // Status & Notification Banners
  static const Color warningBg = Color(0xFFFDF6EE);         // Amber/terracotta offline banner container
  static const Color warningBorder = Color(0xFFE9D2B8);     // Amber offline hairline border
  static const Color warningText = Color(0xFF9A4023);       // Amber headline text
  static const Color warningIcon = Color(0xFFD97706);       // Amber icon glyph

  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFEBF3ED);
  static const Color onSuccess = Color(0xFF2F5238);

  static const Color error = Color(0xFFBA1A1A);             // Crimson error & destructive actions
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);

  // Translucent Scrims
  static const Color scrim = Color(0xB21C1917);             // rgba(28, 25, 23, 0.70) modal backdrop
}
