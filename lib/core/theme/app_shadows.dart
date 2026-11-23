import 'package:flutter/material.dart';

/// Warm Editorial Design System Elevation & Shadow Tokens.
abstract class AppShadows {
  // Level 1: Cards & Subtle Surface Blocks
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A1C1917), // 4% opacity
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Color(0x051C1917), // 2% opacity
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  // Level 2: Docked Audio Player & Bottom Sheets
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x0F1C1917), // 6% opacity
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
    BoxShadow(
      color: Color(0x0A9A4023), // 4% subtle terracotta glow
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];

  // Level 3: Primary Voice Record FAB & Floating Modals
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: Color(0x38C25E3E), // 22% terracotta glow
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
    BoxShadow(
      color: Color(0x141C1917), // 8% base ink drop
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  // Dialog Card Ambient Shadow
  static const List<BoxShadow> dialog = [
    BoxShadow(
      color: Color(0x1F1C1917),
      offset: Offset(0, 12),
      blurRadius: 36,
    ),
  ];
}
