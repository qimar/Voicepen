/// Supabase project configuration for VoicePen Cloud.
///
/// Configure credentials via compile-time environment definitions:
///   flutter run --dart-define-from-file=.env
///
/// If no environment variables are provided, placeholder values are used
/// to allow offline local operation without throwing runtime initialization errors.
abstract class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_placeholder_anon_key',
  );

  /// Returns true if valid production credentials were supplied.
  static bool get isConfigured =>
      url.isNotEmpty &&
      !url.contains('placeholder') &&
      anonKey.isNotEmpty &&
      !anonKey.contains('placeholder');
}
