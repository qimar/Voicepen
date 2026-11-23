import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_page_route.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/services/supabase_auth_service.dart';
import '../../../notes/presentation/screens/library_screen.dart';

/// Mandatory Auth screen for VoicePen Cloud.
///
/// Features:
///  - Warm Editorial terracotta design system
///  - Email & Password (Sign in & Sign up)
///  - Google OAuth sign in
///  - Password reset flow
///  - Smooth validation and user-friendly error banners
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Mode: 0 = Sign In, 1 = Sign Up
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _switchMode(bool signUp) {
    if (_isSignUp == signUp) return;
    setState(() {
      _isSignUp = signUp;
      _errorMessage = null;
    });
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(supabaseAuthServiceProvider);
      if (_isSignUp) {
        final res = await authService.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

        if (!mounted) return;

        // If email confirmation is required by Supabase
        if (res.session == null) {
          _showInfoDialog(
            title: 'Account Created',
            message:
                'We have sent a confirmation email to ${_emailController.text}. Please click the link in your email to verify your account, then sign in.',
          );
          _switchMode(false);
          return;
        }
      } else {
        await authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      // Navigate to Library on successful login
      Navigator.of(context).pushReplacement(
        AppPageRoute(page: const LibraryScreen()),
      );
    } on AuthExceptionWithMessage catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(supabaseAuthServiceProvider);
      await authService.signInWithGoogle();
      // Google OAuth triggers a browser / deep link redirect.
      // onAuthStateChange will detect the session when returning.
    } on AuthExceptionWithMessage catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Google sign-in could not be completed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetController = TextEditingController(text: _emailController.text);
    bool sending = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              title: Text(
                'Reset Password',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your registered email address. We will send you a secure link to reset your password.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.inkPrimary),
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: AppTypography.labelSmall.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.inkMuted)),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email = resetController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() => dialogError = 'Please enter a valid email address.');
                            return;
                          }
                          setDialogState(() {
                            sending = true;
                            dialogError = null;
                          });
                          try {
                            await ref.read(supabaseAuthServiceProvider).sendPasswordResetEmail(email);
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset link sent to your email!'),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: StadiumBorder(),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              sending = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInfoDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: AppTypography.headlineSmall.copyWith(color: AppColors.inkPrimary)),
        content: Text(message, style: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to background auth state changes (e.g. from Google OAuth callback)
    ref.listen(authStateStreamProvider, (prev, next) {
      if (next.asData?.value.session != null && mounted) {
        Navigator.of(context).pushReplacement(
          AppPageRoute(page: const LibraryScreen()),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Emblem & Wordmark
                  Center(
                    child: AppLogo(
                      size: 68,
                      hasShadow: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'VoicePen',
                      style: GoogleFonts.newsreader(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: AppColors.inkPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Sign in to access your synchronized voice library',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Mode Switcher Tabs (Sign In / Sign Up)
                  Container(
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            title: 'Sign In',
                            isSelected: !_isSignUp,
                            onTap: () => _switchMode(false),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            title: 'Create Account',
                            isSelected: _isSignUp,
                            onTap: () => _switchMode(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Message Banner (if any)
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email/Password Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isSignUp) ...[
                          _FormFieldLabel('Your Name (Optional)'),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: AppTypography.bodyLarge.copyWith(color: AppColors.inkPrimary),
                            decoration: _inputDecoration(
                              hint: 'Jane Doe',
                              prefixIcon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _FormFieldLabel('Email Address'),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: AppTypography.bodyLarge.copyWith(color: AppColors.inkPrimary),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your email.';
                            }
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hint: 'name@example.com',
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _FormFieldLabel('Password'),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: AppTypography.bodyLarge.copyWith(color: AppColors.inkPrimary),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your password.';
                            }
                            if (_isSignUp && val.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.inkSubtle,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                        ),

                        // Forgot Password Link (Sign In only)
                        if (!_isSignUp) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Primary Action Button (Sign In / Sign Up)
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitEmailAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Create VoicePen Account' : 'Sign In',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.borderSubtle)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.inkSubtle,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.borderSubtle)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Google Sign-In Button
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _submitGoogleAuth,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GoogleGLogo(size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.inkPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Privacy & Terms disclaimer
                  Text(
                    'By continuing, you agree to VoicePen’s Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.inkSubtle,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.inkSubtle),
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: Icon(prefixIcon, color: AppColors.inkSubtle, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}

class _FormFieldLabel extends StatelessWidget {
  final String label;
  const _FormFieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.inkPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: AppTypography.labelLarge.copyWith(
            color: isSelected ? AppColors.inkPrimary : AppColors.inkMuted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Renders the multi-color Google 'G' icon cleanly without needing an external asset.
class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Blue
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.92, 46.83, 21.34, 46.56, 19.82)
      ..lineTo(24, 19.82)
      ..lineTo(24, 28.79)
      ..lineTo(36.92, 28.79)
      ..cubicTo(36.36, 31.81, 34.66, 34.37, 32.1, 36.08)
      ..lineTo(32.1, 42.18)
      ..lineTo(39.91, 42.18)
      ..cubicTo(44.48, 37.97, 46.98, 31.85, 46.98, 24.55)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(24, 48)
      ..cubicTo(30.48, 48, 35.91, 45.85, 39.91, 42.18)
      ..lineTo(32.1, 36.08)
      ..cubicTo(29.93, 37.53, 27.17, 38.38, 24, 38.38)
      ..cubicTo(17.75, 38.38, 12.47, 34.16, 10.58, 28.49)
      ..lineTo(2.55, 28.49)
      ..lineTo(2.55, 34.71)
      ..cubicTo(6.52, 42.59, 14.62, 48, 24, 48)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(10.58, 28.49)
      ..cubicTo(10.1, 27.06, 9.83, 25.54, 9.83, 24)
      ..cubicTo(9.83, 22.46, 10.1, 20.94, 10.58, 19.51)
      ..lineTo(10.58, 13.29)
      ..lineTo(2.55, 13.29)
      ..cubicTo(0.92, 16.53, 0, 20.16, 0, 24)
      ..cubicTo(0, 27.84, 0.92, 31.47, 2.55, 34.71)
      ..lineTo(10.58, 28.49)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(24, 9.62)
      ..cubicTo(27.52, 9.62, 30.68, 10.83, 33.17, 13.21)
      ..lineTo(40.09, 6.29)
      ..cubicTo(35.91, 2.39, 30.48, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.52, 5.41, 2.55, 13.29)
      ..lineTo(10.58, 19.51)
      ..cubicTo(12.47, 13.84, 17.75, 9.62, 24, 9.62)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
