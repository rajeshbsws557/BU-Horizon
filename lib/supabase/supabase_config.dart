/// Supabase connection configuration.
///
/// The live project's URL and publishable key are baked in as defaults, so
/// every build (plain `flutter run`, IDE launch, release APK) connects to the
/// real backend without needing --dart-define flags. Before this, launching
/// without `--dart-define-from-file=dart_defines.json` silently fell back to
/// the demo Sample* repositories and skipped auth gating entirely.
///
/// The values can still be overridden (e.g. to point at a staging project):
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<publishable-key>
///
/// Passing explicitly EMPTY values restores the UI-only mode with sample data
/// and no auth (used by the "UI only" launch configuration):
///
///   flutter run --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=
///
/// The publishable (formerly "anon") key is safe to ship in a client;
/// row-level security is what protects the data. Never put the service_role
/// key here.
abstract class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mhigxrthygovzwucxxjh.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_KUNeGKK0Rlta-lEdUyiJjQ_sy2lu9pc',
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
