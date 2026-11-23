import 'package:flutter/material.dart';

/// Warm Editorial Design System Radius Tokens.
abstract class AppRadii {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
  static const double xxl = 32.0;
  static const double full = 9999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius roundedXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius roundedFull = BorderRadius.all(Radius.circular(full));

  // Modal Bottom Sheet Top Corners
  static const BorderRadius bottomSheet = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
}
