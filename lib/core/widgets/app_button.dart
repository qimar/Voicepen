import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
}

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final bool isFullWidth;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.isFullWidth = true,
    this.height = 52.0,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null) {
      _controller.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;
    List<BoxShadow> shadows = [];

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bgColor = AppColors.primary;
        textColor = AppColors.onPrimary;
        shadows = AppShadows.card;
        break;
      case AppButtonVariant.secondary:
        bgColor = AppColors.primaryTint;
        textColor = AppColors.primary;
        break;
      case AppButtonVariant.outline:
        bgColor = AppColors.surface;
        textColor = AppColors.inkPrimary;
        border = Border.all(color: AppColors.borderSubtle, width: 1);
        break;
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = AppColors.inkMuted;
        break;
      case AppButtonVariant.destructive:
        bgColor = AppColors.errorContainer;
        textColor = AppColors.error;
        break;
    }

    final content = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: widget.onPressed == null ? bgColor.withValues(alpha: 0.5) : bgColor,
          borderRadius: AppRadii.roundedFull,
          border: border,
          boxShadow: widget.variant == AppButtonVariant.primary ? shadows : null,
        ),
        child: Row(
          mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.leadingIcon != null) ...[
              Icon(widget.leadingIcon, size: 20, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: AppTypography.labelLarge.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(widget.trailingIcon, size: 20, color: textColor),
            ],
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: widget.isFullWidth ? SizedBox(width: double.infinity, child: content) : content,
    );
  }
}
