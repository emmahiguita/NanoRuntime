/// Estado durable de conversaciones archivadas dentro del hub de Nano.
///
/// Archivar aquí solo cambia la organización local del centro de mensajería;
/// nunca afirma haber archivado el chat interno de WhatsApp.
library;

import 'dart:convert';

import '../storage/automation_db_store_client.dart';
import 'conversation_key.dart';

final class ConversationHubArchiveStore {
  static const _section = 'conversation_hub_state';
  static const _maxArchived = 500;

  final Set<String> _archived = {};
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();

  Future<Set<String>> load() async {
    await (_loading ??= _load());
    return Set.unmodifiable(_archived);
  }

  Future<void> _load() async {
    final raw = await AutomationDbStoreClient.instance.section(_section);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['archived'] is! List) {
      throw const FormatException('Invalid conversation hub state');
    }
    for (final value in decoded['archived'] as List) {
      if (value is! String) continue;
      final key = canonicalConversationId(value);
      if (_valid(key)) _archived.add(key);
    }
  }

  Future<Set<String>> setArchived(
    Iterable<String> conversationIds, {
    required bool archived,
  }) async {
    await load();
    final keys = conversationIds
        .map(canonicalConversationId)
        .where(_valid)
        .toSet();
    if (keys.isEmpty) return Set.unmodifiable(_archived);

    final operation = _writes.then((_) async {
      final previous = Set<String>.of(_archived);
      archived ? _archived.addAll(keys) : _archived.removeAll(keys);
      if (_archived.length > _maxArchived) {
        _archived.removeAll(_archived.take(_archived.length - _maxArchived));
      }
      final ok = await AutomationDbStoreClient.instance.putSection(
        _section,
        jsonEncode({'version': 1, 'archived': _archived.toList()}),
      );
      if (!ok) {
        _archived
          ..clear()
          ..addAll(previous);
        throw StateError('Conversation archive persistence rejected');
      }
    });
    _writes = operation.catchError((Object _) {});
    await operation;
    return Set.unmodifiable(_archived);
  }

  static bool _valid(String value) => value.isNotEmpty && value.length <= 3000;
}
