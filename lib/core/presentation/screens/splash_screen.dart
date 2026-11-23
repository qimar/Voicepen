import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_logo.dart';
import '../../../../features/notes/presentation/screens/library_screen.dart';
import '../../../../features/auth/presentation/screens/auth_screen.dart';
import '../../theme/app_page_route.dart';

/// Animated splash screen shown on app launch.
///
/// Animation sequence (~1.8 s total):
///  0–400 ms   → nib fades in + scales up from 0.55 → 1.0
///  200–720 ms → waves bloom outward progressively
///  500–780 ms → wordmark ("VoicePen") fades in
///  2000 ms    → navigate to LibraryScreen (replace)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _nibOpacity;
  late final Animation<double> _nibScale;
  late final Animation<double> _waveProgress;
  late final Animation<double> _wordmarkOpacity;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _nibOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeIn),
      ),
    );

    _nibScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _waveProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.72, curve: Curves.easeOut),
      ),
    );

    _wordmarkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.78, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2000), _navigateToApp);
  }

  void _navigateToApp() {
    if (!mounted || _navigated) return;
    _navigated = true;

    bool isAuthenticated = false;
    try {
      isAuthenticated = Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      // In test environments where Supabase is not initialized, default to unauthenticated
      isAuthenticated = false;
    }

    final targetPage = isAuthenticated ? const LibraryScreen() : const AuthScreen();

    Navigator.of(context).pushReplacement(
      AppPageRoute(page: targetPage),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated logo badge (exact same AppLogo widget as library screen)
                Opacity(
                  opacity: _nibOpacity.value,
                  child: Transform.scale(
                    scale: _nibScale.value,
                    child: AppLogo(
                      size: 110,
                      waveProgress: _waveProgress.value,
                      hasShadow: true,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Wordmark
                Opacity(
                  opacity: _wordmarkOpacity.value,
                  child: Text(
                    'VoicePen',
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.inkPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Opacity(
                  opacity: _wordmarkOpacity.value,
                  child: Text(
                    'Speak. Polish. Preserve.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.inkMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


