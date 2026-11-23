import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bounceable.dart';

class MicPermissionDialog extends StatelessWidget {
  final VoidCallback onDismiss;

  const MicPermissionDialog({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF9F4),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkPrimary.withValues(alpha: 0.35),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Icon Container with Warning Badge matching Stitch
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.peachTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mic_off,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                ),
                // Miniature Alert / Warning Badge
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFCF9F4), width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Headline
            Text(
              'Microphone Access Required',
              style: GoogleFonts.newsreader(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.inkPrimary,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Body Copy
            Text(
              'VoicePen needs permission to use your microphone so it can listen to your voice memos and polish them into clear notes. Please enable microphone access in your device settings.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.inkMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),

            // Open Android Settings Primary Button
            AppBounceable(
              onTap: () async {
                await openAppSettings();
                onDismiss();
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadii.roundedFull,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Open Android Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.open_in_new, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Not Now Text Button
            AppBounceable(
              onTap: onDismiss,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: const BoxDecoration(color: Colors.transparent),
                child: const Center(
                  child: Text(
                    'Not Now',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w600,
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
