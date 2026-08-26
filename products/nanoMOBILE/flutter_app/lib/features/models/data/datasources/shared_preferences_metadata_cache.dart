/// Implementación de caché local con SharedPreferences y memoria RAM (SRP & DIP).
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i_model_metadata_datasource.dart';

class SharedPreferencesMetadataCache implements IModelLocalMetadataCache {
  static const String _prefPrefix = 'hf_meta_cache_';
  final Map<String, RemoteModelMetadataDto> _memoryCache = {};
  final Map<String, DateTime> _timestamps = {};
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefPrefix));
      for (final key in keys) {
        final repoId = key.substring(_prefPrefix.length);
        final raw = prefs.getString(key);
        if (raw != null) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final timestamp =
              DateTime.tryParse(map['_cached_at'] as String? ?? '') ??
              DateTime.now();
          final meta = RemoteModelMetadataDto.fromJson(map);
          _memoryCache[repoId] = meta;
          _timestamps[repoId] = timestamp;
        }
      }
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error en SharedPreferencesMetadataCache: $e');
      }
    }
  }

  @override
  RemoteModelMetadataDto? get(String repoId) => _memoryCache[repoId];

  @override
  DateTime? getTimestamp(String repoId) => _timestamps[repoId];

  @override
  bool isFresh(String repoId, Duration ttl) {
    final ts = _timestamps[repoId];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < ttl;
  }

  @override
  Future<void> save(
    String repoId,
    RemoteModelMetadataDto metadata,
    DateTime timestamp,
  ) async {
    _memoryCache[repoId] = metadata;
    _timestamps[repoId] = timestamp;
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = metadata.toJson()
        ..['_cached_at'] = timestamp.toIso8601String();
      await prefs.setString('$_prefPrefix$repoId', jsonEncode(toSave));
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando en SharedPreferencesMetadataCache: $e');
      }
    }
  }
}
