import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bounceable.dart';

class DiscardRecordingDialog extends StatelessWidget {
  final String durationText;
  final VoidCallback onDiscard;
  final VoidCallback onKeep;

  const DiscardRecordingDialog({
    super.key,
    this.durationText = '02:14',
    required this.onDiscard,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.roundedXl,
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkPrimary.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Circular Warning Trash Icon matching Stitch
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: AppColors.peachTint,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.delete_outline,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Headline
            Text(
              'Discard Recording?',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.inkPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Body text
            Text(
              'Are you sure you want to discard this $durationText voice memo? Your recording will not be saved and this action cannot be undone.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.inkMuted,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),

            // Keep Recording Primary Button
            AppBounceable(
              onTap: onKeep,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: const Center(
                  child: Text(
                    'Keep Recording',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Discard Destructive Button
            AppBounceable(
              onTap: onDiscard,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: const BoxDecoration(color: Colors.transparent),
                child: const Center(
                  child: Text(
                    'Discard Memo',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
