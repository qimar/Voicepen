import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The official VoicePen app logo badge.
/// Renders the signature "Quill & Soundwave" brand emblem (Variant A)
/// in the Warm Editorial terracotta palette.
///
/// This is the SINGLE SOURCE OF TRUTH for the app logo across:
///  - Splash screen (animated via [waveProgress], larger with [hasShadow])
///  - Library screen app bar (next to VoicePen title)
///  - Settings & Paywall screens
///
/// Shape: Rounded rectangle with continuous smooth curves (matching Android icon).
class AppLogo extends StatelessWidget {
  final double size;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isCircle;
  final double waveProgress;
  final bool hasShadow;

  const AppLogo({
    super.key,
    this.size = 38,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
    this.isCircle = false,
    this.waveProgress = 1.0,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.peachTint,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(size * 0.24),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.07),
                ),
              ]
            : null,
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.78,
          height: size * 0.78,
          child: CustomPaint(
            painter: QuillWavePainter(
              penColor: iconColor ?? AppColors.primary,
              baseColor: AppColors.primaryDark,
              accentColor: AppColors.primaryLight,
              slitColor: AppColors.background,
              waveProgress: waveProgress,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the "Quill & Soundwave" nib icon.
///
/// Coordinate space: normalized 128×128 viewBox (same as master SVG icon).
/// All coordinates match the master SVG exactly for 100% visual identity.
class QuillWavePainter extends CustomPainter {
  final Color penColor;
  final Color baseColor;
  final Color accentColor;
  final Color slitColor;
  // Wave progress for animation (0.0–1.0). 1.0 = fully visible.
  final double waveProgress;

  const QuillWavePainter({
    required this.penColor,
    required this.baseColor,
    required this.accentColor,
    this.slitColor = AppColors.background,
    this.waveProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 128.0;
    canvas.save();
    canvas.scale(s, s);

    _drawNib(canvas);
    _drawWaves(canvas);

    canvas.restore();
  }

  void _drawNib(Canvas canvas) {
    // Nib body — symmetric around x=64, tip at y=22, base at y=88
    final nibPath = Path()
      ..moveTo(64, 22)                     // tip (top center)
      ..lineTo(50, 42)                     // upper-left shoulder
      ..cubicTo(47, 50, 44, 60, 44, 68)   // left side curve
      ..lineTo(44, 88)                     // left base corner
      ..lineTo(84, 88)                     // right base corner
      ..lineTo(84, 68)                     // right side up
      ..cubicTo(84, 60, 81, 50, 78, 42)   // upper-right shoulder
      ..close();                           // back to tip

    final penPaint = Paint()
      ..shader = LinearGradient(
        colors: [penColor, AppColors.secondary],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(44, 22, 40, 66))
      ..style = PaintingStyle.fill;

    canvas.drawPath(nibPath, penPaint);

    // Base trim bar
    final baseTrimPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 87, 44, 7),
        const Radius.circular(3.5),
      ),
      baseTrimPaint,
    );

    // Shoulder accent arc (upper highlight)
    final shoulderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final shoulderPath = Path()
      ..moveTo(50, 44)
      ..cubicTo(56, 40, 58, 38, 64, 38)
      ..cubicTo(70, 38, 74, 40, 78, 44);
    canvas.drawPath(shoulderPath, shoulderPaint);

    // Center breathing channel (slit)
    final slitPaint = Paint()
      ..color = slitColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(64, 22), const Offset(64, 58), slitPaint);

    // Breather hole
    final holePaint = Paint()
      ..color = slitColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(64, 58), 4, holePaint);
  }

  void _drawWaves(Canvas canvas) {
    if (waveProgress <= 0) return;

    // Wave 1 — radius ~20, opacity 0.50
    final wave1Paint = Paint()
      ..color = penColor.withValues(alpha: 0.50 * waveProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Wave 2 — radius ~32, opacity 0.30
    final wave2Paint = Paint()
      ..color = penColor.withValues(alpha: 0.30 * waveProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Wave 3 — radius ~46, opacity 0.15
    final wave3Paint = Paint()
      ..color = penColor.withValues(alpha: 0.15 * waveProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const startAngle = -0.95; // radians — upper-right
    const sweepAngle = 1.20;  // radians — arc to lower-right

    canvas.drawArc(
      Rect.fromCircle(center: const Offset(64, 58), radius: 20),
      startAngle, sweepAngle, false, wave1Paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(64, 58), radius: 32),
      startAngle, sweepAngle, false, wave2Paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(64, 58), radius: 46),
      startAngle, sweepAngle, false, wave3Paint,
    );
  }

  @override
  bool shouldRepaint(covariant QuillWavePainter oldDelegate) {
    return oldDelegate.penColor != penColor ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.slitColor != slitColor ||
        oldDelegate.waveProgress != waveProgress;
  }
}
