/// Estado durable de conversaciones archivadas y ocultadas (quitadas) en el hub.
///
/// - QUÉ HACE: Persiste en SQLite (`conversation_hub_state`) qué conversaciones
///   están archivadas o fueron quitadas del centro de Nano.
/// - CÓMO FUNCIONA: Guarda `archived` (Set<String>) y `removed` (Map<String, int>
///   con `removedAtMs`). Si un chat quitado recibe un mensaje posterior a
///   `removedAtMs`, vuelve a mostrarse automáticamente.
/// - POR QUÉ: Evita que al pulsar "Quitar del centro de Nano" el chat reaparezca
///   como zombie desde el historial SQLite o desde WhatsApp Web (< 200 líneas).
library;

import 'dart:convert';

import '../storage/automation_db_store_client.dart';
import 'conversation_key.dart';

final class ConversationHubArchiveStore {
  static const _section = 'conversation_hub_state';
  static const _maxEntries = 500;

  final Set<String> _archived = {};
  final Map<String, int> _removedAtMs = {};
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();

  Future<Set<String>> load() async {
    await _ensureLoaded();
    return Set.unmodifiable(_archived);
  }

  Future<Map<String, int>> loadRemoved() async {
    await _ensureLoaded();
    return Map.unmodifiable(_removedAtMs);
  }

  Future<void> _ensureLoaded() async {
    await (_loading ??= _load().catchError((Object error) {
      _loading = null;
      throw error;
    }));
  }

  Future<void> _load() async {
    final raw = await AutomationDbStoreClient.instance.section(_section);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final archivedList = decoded['archived'];
      if (archivedList is List) {
        for (final value in archivedList) {
          if (value is! String) continue;
          final key = canonicalConversationId(value);
          if (_valid(key)) _archived.add(key);
        }
      }
      final removedMap = decoded['removed'];
      if (removedMap is Map) {
        removedMap.forEach((rawKey, rawTs) {
          if (rawKey is! String || rawTs is! num) return;
          final key = canonicalConversationId(rawKey);
          if (_valid(key)) _removedAtMs[key] = rawTs.toInt();
        });
      }
    } catch (_) {
      // Tolera json no parseable sin romper el hub.
    }
  }

  Future<Set<String>> setArchived(
    Iterable<String> conversationIds, {
    required bool archived,
  }) async {
    await _ensureLoaded();
    final keys = conversationIds.map(canonicalConversationId).where(_valid).toSet();
    if (keys.isEmpty) return Set.unmodifiable(_archived);

    await _mutate(() {
      if (archived) {
        _archived.addAll(keys);
        for (final k in keys) {
          _removedAtMs.remove(k);
        }
      } else {
        _archived.removeAll(keys);
      }
    });
    return Set.unmodifiable(_archived);
  }

  Future<Map<String, int>> setRemoved(
    Iterable<String> conversationIds, {
    required int removedAtMs,
  }) async {
    await _ensureLoaded();
    final keys = conversationIds.map(canonicalConversationId).where(_valid).toSet();
    if (keys.isEmpty) return Map.unmodifiable(_removedAtMs);

    await _mutate(() {
      _archived.removeAll(keys);
      for (final key in keys) {
        _removedAtMs.remove(key);
        _removedAtMs[key] = removedAtMs;
      }
    });
    return Map.unmodifiable(_removedAtMs);
  }

  Future<void> _mutate(void Function() applyChanges) async {
    final operation = _writes.then((_) async {
      final prevArchived = Set<String>.of(_archived);
      final prevRemoved = Map<String, int>.of(_removedAtMs);
      applyChanges();
      if (_archived.length > _maxEntries) {
        _archived.removeAll(_archived.take(_archived.length - _maxEntries));
      }
      while (_removedAtMs.length > _maxEntries) {
        _removedAtMs.remove(_removedAtMs.keys.first);
      }
      final ok = await AutomationDbStoreClient.instance.putSection(
        _section,
        jsonEncode({
          'version': 2,
          'archived': _archived.toList(),
          'removed': _removedAtMs,
        }),
      );
      if (!ok) {
        _archived
          ..clear()
          ..addAll(prevArchived);
        _removedAtMs
          ..clear()
          ..addAll(prevRemoved);
        throw StateError('Conversation hub state persistence rejected');
      }
    });
    _writes = operation.catchError((Object _) {});
    await operation;
  }

  static bool _valid(String value) => value.isNotEmpty && value.length <= 3000;
}
