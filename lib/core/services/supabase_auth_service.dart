import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the [SupabaseAuthService] instance.
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(Supabase.instance.client);
});

/// Stream of auth state changes (logged in, logged out, user updated).
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final service = ref.watch(supabaseAuthServiceProvider);
  return service.authStateChanges;
});

/// Current authenticated user (or null if signed out).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateStreamProvider);
  return authState.asData?.value.session?.user ??
      Supabase.instance.client.auth.currentUser;
});

/// Exception wrapper for user-facing auth error messaging.
class AuthExceptionWithMessage implements Exception {
  final String message;
  const AuthExceptionWithMessage(this.message);

  @override
  String toString() => message;
}

/// Service handling all Supabase Authentication logic for VoicePen.
class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

  /// Current session or null.
  Session? get currentSession => _client.auth.currentSession;

  /// Current authenticated user or null.
  User? get currentUser => _client.auth.currentUser;

  /// Whether a user is currently signed in.
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Stream of Supabase Auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with Email and Password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthExceptionWithMessage(_mapAuthError(e.message));
    } catch (e) {
      throw AuthExceptionWithMessage('Failed to sign in. Please check your connection.');
    }
  }

  /// Sign up with Email and Password.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: displayName != null && displayName.isNotEmpty
            ? {'full_name': displayName.trim()}
            : null,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthExceptionWithMessage(_mapAuthError(e.message));
    } catch (e) {
      throw AuthExceptionWithMessage('Failed to create account. Please try again.');
    }
  }

  /// Initiates Google OAuth Sign-In.
  Future<bool> signInWithGoogle() async {
    try {
      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.voicepen://login-callback/',
      );
      return success;
    } on AuthException catch (e) {
      throw AuthExceptionWithMessage(_mapAuthError(e.message));
    } catch (e) {
      throw AuthExceptionWithMessage('Google sign-in could not be completed.');
    }
  }

  /// Send password reset link to user email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AuthExceptionWithMessage(_mapAuthError(e.message));
    } catch (e) {
      throw AuthExceptionWithMessage('Could not send password reset email.');
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignore sign-out failure
    }
  }

  /// Delete the current user's account and all associated cloud data
  /// (Complies with Play Store Account Deletion policy).
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_user_account');
      await signOut();
    } on AuthException catch (e) {
      throw AuthExceptionWithMessage(e.message);
    } catch (e) {
      throw const AuthExceptionWithMessage('Failed to delete account. Please try again.');
    }
  }

  /// Maps Supabase raw error strings to clean, user-friendly language.
  String _mapAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_grant')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already in use')) {
      return 'An account already exists with this email.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password must be at least 6 characters long.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please check your email and confirm your address before logging in.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many login attempts. Please wait a moment and try again.';
    }
    return raw;
  }
}
