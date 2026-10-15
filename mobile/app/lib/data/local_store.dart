/// Tiny JSON key-value store on top of `shared_preferences` (localStorage on
/// web). Keeps the attendee's client state across reloads.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preloaded in `main()` and overridden in the `ProviderScope`, so Notifiers
/// can read their saved state synchronously in `build()`. `null` (the default,
/// e.g. in tests that don't care) means nothing is persisted.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);

class LocalStore {
  const LocalStore(this._prefs);

  final SharedPreferences? _prefs;

  static const _prefix = 'eho.';

  /// Decoded and parsed value for [key], or null when missing. Corrupt or
  /// unreadable data is cleared and ignored.
  T? readAs<T>(String key, T Function(Object json) parse) {
    final prefs = _prefs;
    if (prefs == null) return null;
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json == null ? null : parse(json);
    } catch (e) {
      debugPrint('Ignoring unreadable saved state "$key": $e');
      prefs.remove('$_prefix$key');
      return null;
    }
  }

  void write(String key, Object? json) {
    final prefs = _prefs;
    if (prefs == null) return;
    if (json == null) {
      prefs.remove('$_prefix$key');
    } else {
      prefs.setString('$_prefix$key', jsonEncode(json));
    }
  }
}
