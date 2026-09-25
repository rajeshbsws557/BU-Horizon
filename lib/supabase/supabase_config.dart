/// Supabase connection configuration.
///
/// Credentials are injected at build time via `--dart-define-from-file` or
/// individual `--dart-define` flags — no secrets are stored in source control.
///
///   flutter run --dart-define-from-file=dart_defines.json
///
/// Or pass values individually:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<publishable-key>
///
/// When both values are left empty (the default), the app runs in UI-only
/// mode with sample data and no auth — useful for design work and widget tests.
///
/// The publishable (formerly "anon") key is safe to ship in a client;
/// row-level security is what protects the data. Never put the service_role
/// key here.
abstract class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Whether credentials are present at all. Only false when both values are
  /// explicitly blanked with --dart-define (UI-only design builds).
  static bool get hasCredentials => url.isNotEmpty && anonKey.isNotEmpty;

  static bool _initialized = false;

  /// True once `Supabase.initialize` has completed in main(). Everything that
  /// talks to Supabase (DI bindings, auth gating, queries) checks this.
  /// Widget tests never run main(), so it stays false there and the app
  /// falls back to sample data with no auth gating — same as before.
  static bool get isConfigured => _initialized;

  /// Called from main() after Supabase.initialize succeeds.
  static void markInitialized() => _initialized = true;
}
