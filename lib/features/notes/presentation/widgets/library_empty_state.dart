import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radii.dart';

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Circular Tactile Artwork with Concentric Rings
          Center(
            child: SizedBox(
              width: 208,
              height: 208,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Diffused Glow
                  Container(
                    width: 208,
                    height: 208,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.peachTint.withValues(alpha: 0.6),
                    ),
                  ),
                  // Concentric Ring 3 (Outer ambient paper container)
                  Container(
                    width: 192,
                    height: 192,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerLow,
                      border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                    ),
                  ),
                  // Orbiting Sparkle Badge
                  Positioned(
                    top: 14,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.peachTint,
                        borderRadius: AppRadii.roundedFull,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                  // Concentric Ring 2 (Middle paper layer)
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.inkPrimary.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Subtle Audio Metric Capsule
                  Positioned(
                    bottom: 22,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadii.roundedFull,
                        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.equalizer, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Studio Voice',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Core Disc with Waveform Bars
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.peachTint,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(width: 3.5, height: 12, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 3.5, height: 22, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 4.5, height: 32, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 3.5, height: 26, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 4.5, height: 36, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 3.5, height: 18, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Container(width: 3.5, height: 8, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'VOICE',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Headline: Newsreader Editorial Serif
          Text(
            'Your thoughts, untangled.',
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: AppColors.inkPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // Body Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Capture your raw brain dumps while walking, driving, or thinking out loud. VoicePen will structure them into clear, polished writing.',
              style: AppTypography.bodyMedium.copyWith(
                height: 1.55,
                color: AppColors.inkMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          // Direct Prompt Instruction Pill pointing toward FAB
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: AppRadii.roundedFull,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Tap the microphone below to record your first memo',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
