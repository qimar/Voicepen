import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isRecording;
  final double progress; // 0.0 to 1.0 for playback scrubbing
  final double height;
  final int barCount;

  const WaveformVisualizer({
    super.key,
    this.isRecording = false,
    this.progress = 0.0,
    this.height = 48.0,
    this.barCount = 32,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isRecording) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRecording && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _WaveformPainter(
            barCount: widget.barCount,
            progress: widget.progress,
            isRecording: widget.isRecording,
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final int barCount;
  final double progress;
  final bool isRecording;
  final double animationValue;

  _WaveformPainter({
    required this.barCount,
    required this.progress,
    required this.isRecording,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final barWidth = 3.5;
    final totalSpacing = size.width - (barCount * barWidth);
    final spacing = totalSpacing / (barCount - 1).clamp(1, 999);

    final activePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final playedBarIndex = (progress * barCount).floor();

    for (int i = 0; i < barCount; i++) {
      double normalizedHeight;

      if (isRecording) {
        // Dynamic oscillating sine wave simulation
        final wave1 = math.sin((i * 0.35) + (animationValue * math.pi * 2));
        final wave2 = math.cos((i * 0.2) - (animationValue * math.pi * 2));
        final combined = ((wave1 + wave2) / 2).abs();
        normalizedHeight = 0.2 + (combined * 0.75);
      } else {
        // Fixed aesthetic speech envelope pattern
        final x = (i - (barCount / 2)) / (barCount / 2);
        final base = math.exp(-2.5 * x * x);
        final harmonic = 0.25 * math.sin(i * 1.2);
        normalizedHeight = (base + harmonic).clamp(0.18, 0.95);
      }

      final barHeight = size.height * normalizedHeight;
      final xPos = i * (barWidth + spacing);
      final yPos = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(xPos, yPos, barWidth, barHeight),
        const Radius.circular(2),
      );

      final paint = isRecording || i <= playedBarIndex ? activePaint : inactivePaint;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.progress != progress ||
        oldDelegate.isRecording != isRecording;
  }
}
