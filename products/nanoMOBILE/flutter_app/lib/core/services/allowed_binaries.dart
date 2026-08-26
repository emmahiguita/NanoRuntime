import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Loads and caches the allowed binaries whitelist from assets/config/allowed_binaries.json.
///
/// Previously hardcoded in nanoshell_ffi.dart as a static const. Moved to config
/// so new binaries can be added via asset update without recompilation.
/// The whitelist is validated at load time; malformed JSON → empty set → all blocked.
class AllowedBinaries {
  static Set<String>? _cache;
  static Future<Set<String>>? _loadFuture;

  /// Returns the cached set, loading from assets on first call.
  static Future<Set<String>> load() async {
    if (_cache != null) return _cache!;
    return _loadFuture ??= _loadFromAssets();
  }

  static Future<Set<String>> _loadFromAssets() async {
    try {
      final json = await rootBundle.loadString(
        'assets/config/allowed_binaries.json',
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final list = (parsed['allowed'] as List?)?.cast<String>() ?? [];
      _cache = list.toSet();
    } catch (_) {
      _cache = {}; // Fail closed: no binaries allowed if config is unreadable.
    }
    return _cache!;
  }

  /// Synchronous check against the cached set. Returns false if cache not loaded yet.
  static bool isAllowed(String basename, {Set<String>? cache}) {
    final allowed = cache ?? _cache;
    if (allowed == null) return false;
    return allowed.any((a) => basename == a || basename.startsWith('$a.'));
  }
}
