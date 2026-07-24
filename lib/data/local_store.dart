import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../di/di.dart';

/// On-device persistence layer.
///
/// Two responsibilities:
///  * **Settings** — small durable preferences such as the chosen theme.
///  * **Offline cache** — the raw rows of the last successful backend read, so
///    the app can still render the most recent data when the network drops.
///
/// The cache stores the *raw Supabase rows* (not mapped models) so the mapping
/// logic in the repositories stays single-sourced: an offline read replays the
/// exact same `_fromRow` transforms against the cached JSON.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'settings.theme_mode';
  static const _cachePrefix = 'cache.';

  // --- Settings -------------------------------------------------------------

  /// 'light' | 'dark' | null (never chosen).
  String? get themeMode => _prefs.getString(_themeKey);
  Future<void> setThemeMode(String mode) => _prefs.setString(_themeKey, mode);

  bool? getFlag(String key) => _prefs.getBool('settings.$key');
  Future<void> setFlag(String key, bool value) =>
      _prefs.setBool('settings.$key', value);

  // --- Offline cache --------------------------------------------------------

  List<Map<String, dynamic>>? readRows(String key) {
    final raw = _prefs.getString('$_cachePrefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeRows(String key, List<Map<String, dynamic>> rows) =>
      _prefs.setString('$_cachePrefix$key', jsonEncode(rows));

  /// Drops every cached read (e.g. on sign-out) while keeping settings.
  Future<void> clearCache() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(_cachePrefix)) await _prefs.remove(key);
    }
  }
}

/// Read-through cache for a Supabase list query.
///
/// Fetches live rows and refreshes the cache on success; on any failure
/// (typically offline) it falls back to the last cached rows for [cacheKey],
/// and only rethrows when nothing has ever been cached.
Future<List<Map<String, dynamic>>> cachedRows(
  String cacheKey,
  Future<List<Map<String, dynamic>>> Function() fetch,
) async {
  final store = getIt.isRegistered<LocalStore>() ? getIt<LocalStore>() : null;
  try {
    final rows = await fetch();
    await store?.writeRows(cacheKey, rows);
    return rows;
  } catch (_) {
    final cached = store?.readRows(cacheKey);
    if (cached != null) return cached;
    rethrow;
  }
}
