import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bounceable.dart';

enum _ParticleShape { ribbon, star, circle }

class _ConfettiParticle {
  final double relativeX; // 0.0 to 1.0 of dialog width
  final double horizontalDrift; // lateral spread in px
  final double startY; // initial vertical offset
  final double fallDistance; // total distance fell
  final double size;
  final double swayAmp;
  final double swayFreq;
  final double rotationSpeed;
  final double startRotation;
  final double delay; // normalized delay before fall begins (0.0 to 0.3)
  final Color color;
  final _ParticleShape shape;

  const _ConfettiParticle({
    required this.relativeX,
    required this.horizontalDrift,
    required this.startY,
    required this.fallDistance,
    required this.size,
    required this.swayAmp,
    required this.swayFreq,
    required this.rotationSpeed,
    required this.startRotation,
    required this.delay,
    required this.color,
    required this.shape,
  });
}

class ProCelebrationDialog extends StatefulWidget {
  final VoidCallback onStartRecording;

  const ProCelebrationDialog({
    super.key,
    required this.onStartRecording,
  });

  @override
  State<ProCelebrationDialog> createState() => _ProCelebrationDialogState();
}

class _ProCelebrationDialogState extends State<ProCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<_ConfettiParticle> _particles;

  static const List<Color> _palette = [
    AppColors.primary,
    Color(0xFFD97706), // warm amber
    Color(0xFFF59E0B), // bright gold
    Color(0xFF1E824C), // emerald green
    Color(0xFFFFB299), // soft peach
    Color(0xFFE27B58), // coral
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) HapticFeedback.mediumImpact();
    });

    _particles = _generateParticles(42);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  List<_ConfettiParticle> _generateParticles(int count) {
    final rng = math.Random(42);
    return List.generate(count, (i) {
      final shapes = [_ParticleShape.ribbon, _ParticleShape.star, _ParticleShape.circle];
      final shape = shapes[i % shapes.length];
      return _ConfettiParticle(
        relativeX: rng.nextDouble(),
        horizontalDrift: (rng.nextDouble() - 0.5) * 60,
        startY: -20 - rng.nextDouble() * 30,
        fallDistance: 320 + rng.nextDouble() * 260,
        size: shape == _ParticleShape.star ? 14 + rng.nextDouble() * 8 : (shape == _ParticleShape.circle ? 6 + rng.nextDouble() * 4 : 8 + rng.nextDouble() * 6),
        swayAmp: 10 + rng.nextDouble() * 18,
        swayFreq: 1.5 + rng.nextDouble() * 2.5,
        rotationSpeed: 2 + rng.nextDouble() * 6,
        startRotation: rng.nextDouble() * math.pi * 2,
        delay: rng.nextDouble() * 0.28,
        color: _palette[rng.nextInt(_palette.length)],
        shape: shape,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF9F4),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkPrimary.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebratory Medallion Badge (Clean, without checkmark)
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.peachTint,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.edit_note,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Editorial Headline
                Text(
                  'Welcome to VoicePen Pro!',
                  style: GoogleFonts.newsreader(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkPrimary,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.peachTint,
                    borderRadius: AppRadii.roundedFull,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIFETIME ACCESS UNLOCKED',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Indie Note
                Text(
                  'Thank you for supporting solo indie development! All limits have been permanently lifted on this device:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Structured Benefits Box matching Stitch
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedMd,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _buildBenefitRow('Unlimited recording length (no 5-minute cap)'),
                      const SizedBox(height: 8),
                      _buildBenefitRow('100% private on-device transcription'),
                      const SizedBox(height: 8),
                      _buildBenefitRow('Custom AI tone presets & style cloning'),
                      const SizedBox(height: 8),
                      _buildBenefitRow('Audio imports & ad-free forever'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary CTA Action Button
                AppBounceable(
                  onTap: widget.onStartRecording,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadii.roundedFull,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Start Dictating Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.mic, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Celebratory Falling Confetti & Sparkles Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _confettiController.value,
                        particles: _particles,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: AppColors.peachTint,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check, size: 12, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (progress < p.delay) continue;
      final localT = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);

      // Curved physics: faster fall at start, decelerating air drag
      final y = p.startY + p.fallDistance * Curves.easeOutQuad.transform(localT);

      // Horizontal sway (gentle breeze)
      final sway = math.sin(localT * math.pi * 2 * p.swayFreq) * p.swayAmp;
      final x = (p.relativeX * size.width) + (p.horizontalDrift * localT) + sway;

      // Rotation around z and pseudo-3D flip
      final angle = p.startRotation + (p.rotationSpeed * localT * math.pi * 2);
      final flip = math.cos(angle * 1.5);

      // Smooth fade-out in final 25% of lifetime
      final opacity = localT > 0.75
          ? ((1.0 - localT) / 0.25).clamp(0.0, 1.0)
          : (localT < 0.08 ? (localT / 0.08).clamp(0.0, 1.0) : 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      switch (p.shape) {
        case _ParticleShape.ribbon:
          final rectWidth = p.size;
          final rectHeight = p.size * 0.45 * flip.abs();
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: rectWidth, height: math.max(1.5, rectHeight)),
              const Radius.circular(1.5),
            ),
            paint,
          );
          break;

        case _ParticleShape.star:
          _drawStar(canvas, paint, p.size * (0.8 + 0.3 * flip.abs()));
          break;

        case _ParticleShape.circle:
          canvas.drawCircle(Offset.zero, (p.size * 0.45), paint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double radius) {
    final path = Path();
    const int points = 4;
    final double innerRadius = radius * 0.32;
    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? radius : innerRadius;
      final double theta = (i * math.pi) / points;
      final double px = r * math.cos(theta);
      final double py = r * math.sin(theta);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
