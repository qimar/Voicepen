import 'package:flutter/material.dart';

/// Smooth, editorial-grade page transition route:
/// Slides horizontally with a subtle fade and cubic ease curve.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.08, 0.0);
            const end = Offset.zero;
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final slideAnimation = Tween<Offset>(begin: begin, end: end).animate(curve);
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
}
