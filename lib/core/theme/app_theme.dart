import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

/// Complete Warm Editorial ThemeData definition for VoicePen.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryTint,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: Color(0xFF74240A),
        surface: AppColors.surface,
        onSurface: AppColors.inkPrimary,
        onSurfaceVariant: AppColors.inkMuted,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: Color(0xFF93000A),
        outline: AppColors.inkSubtle,
        outlineVariant: AppColors.borderSubtle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.inkPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedMd,
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.bottomSheet),
        dragHandleColor: AppColors.borderSubtle,
        dragHandleSize: Size(44, 5),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedXl,
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.inkSubtle),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
