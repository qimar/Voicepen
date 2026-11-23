import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/state/notes_state.dart';
import '../../../../core/widgets/app_bounceable.dart';
import '../../../../core/widgets/app_logo.dart';
import '../widgets/pro_celebration_dialog.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  void _unlockPro(BuildContext context, WidgetRef ref) {
    HapticFeedback.heavyImpact();
    ref.read(notesProvider.notifier).setProUser(true);

    showDialog(
      context: context,
      barrierColor: AppColors.scrim,
      barrierDismissible: false,
      builder: (_) => ProCelebrationDialog(
        onStartRecording: () {
          // Navigate directly to root (LibraryScreen) with all notes & mic
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  void _restorePurchases(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    ref.read(notesProvider.notifier).setProUser(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Purchases restored: Lifetime Pro active!'),
        backgroundColor: AppColors.inkPrimary,
        behavior: SnackBarBehavior.floating,
        shape: StadiumBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 170),
              child: Column(
                children: [
                  // Top App Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppBounceable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.card,
                          ),
                          child: const Center(
                            child: Icon(Icons.close, size: 20, color: AppColors.inkPrimary),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: AppColors.peachTint,
                          borderRadius: AppRadii.roundedFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'PRO PASS',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Hero Value Proposition
                  Column(
                    children: [
                      const AppLogo(size: 58, iconSize: 34, isCircle: false),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, size: 15, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'UNRESTRICTED VOICE CRAFT',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'VoicePen Pro',
                        style: GoogleFonts.newsreader(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Think Out Loud. Own It Forever.',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Zero Subscriptions Banner matching Stitch
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadii.roundedMd,
                      border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.peachTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.all_inclusive, size: 18, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zero Subscriptions. No Recurring Monthly Bills.',
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pay once today, keep and evolve your voice journal for life.',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Hero Pricing Card ($4.99 USD) with ONE-TIME PURCHASE badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.roundedLg,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'LIFETIME PASS',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '\$4.99',
                                  style: GoogleFonts.newsreader(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'USD',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Lifetime access • Never pay again',
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(height: 1, color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Standard AI apps',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                    Text(
                                      '\$99 / year',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.inkSubtle,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.peachTint,
                                    borderRadius: AppRadii.roundedFull,
                                  ),
                                  child: Text(
                                    'Save 95% today',
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Floating Badge
                      Positioned(
                        top: -12,
                        right: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppRadii.roundedFull,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'ONE-TIME PURCHASE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Feature Checklist Box
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.roundedLg,
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'What You Unlock',
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                            Text(
                              'Complete Pro Bundle',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.inkMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureRow(
                          icon: Icons.bolt,
                          title: 'Unlimited Recording Duration',
                          description: 'Speak for hours without interruptions or 15-minute caps.',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          icon: Icons.lock_outline,
                          title: '100% Private On-Device Transcription',
                          description: 'Recordings & SQLite notes stay strictly on your phone.',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          icon: Icons.auto_awesome,
                          title: 'Custom AI Writing Tones & Control',
                          description: 'All 7 editorial presets and 3 intensity levels.',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          icon: Icons.key,
                          title: 'Bring Your Own Key (BYOK)',
                          description: 'Connect Google AI Studio key for unlimited quota.',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          icon: Icons.block,
                          title: '100% Ad-Free Experience',
                          description: 'Distraction-free environment honoring your stream of thought.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Money-Back Guarantee
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadii.roundedMd,
                      border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '30-day satisfaction guarantee. Backed by Google Play purchase protection.',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Bottom CTA Bar with Fixed Padding
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.8))),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.inkPrimary.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBounceable(
                      onTap: () => _unlockPro(context, ref),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadii.roundedFull,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Unlock Lifetime Access for \$4.99',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 12, color: AppColors.inkSubtle),
                        const SizedBox(width: 4),
                        Text(
                          'Secured with Google Play In-App Billing',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkSubtle,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppBounceable(
                          onTap: () => _restorePurchases(context, ref),
                          child: Text(
                            'Restore Existing Purchase',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.inkMuted,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: AppColors.borderSubtle)),
                        const SizedBox(width: 8),
                        Text(
                          'Terms & Privacy',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.peachTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Icon(icon, size: 16, color: AppColors.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
