import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

class AppPillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isSolidSelected; // When true, uses filled terracotta on selection

  const AppPillChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.isSolidSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border border;

    if (isSelected) {
      if (isSolidSelected) {
        bgColor = AppColors.primary;
        textColor = Colors.white;
        border = Border.all(color: AppColors.primary, width: 1);
      } else {
        bgColor = AppColors.primaryTint;
        textColor = AppColors.primary;
        border = Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1);
      }
    } else {
      bgColor = AppColors.surface;
      textColor = AppColors.inkMuted;
      border = Border.all(color: AppColors.borderSubtle, width: 1);
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: AppRadii.roundedFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadii.roundedFull,
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
