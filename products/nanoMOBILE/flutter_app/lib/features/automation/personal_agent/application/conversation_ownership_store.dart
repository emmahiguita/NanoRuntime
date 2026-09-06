/// PERSONA-HANDOFF-03 — store de ownership por conversación.
///
/// Contrato puro (consultas síncronas: el DecisionEngine decide en caliente):
/// PERSONA-STORAGE-04 aporta la implementación SQLite (sección "ownership",
/// mismo patrón de reemplazo atómico que dedupe/rate/memory).
library;

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../engine/storage/automation_db_store_client.dart';
import '../domain/conversation_owner.dart';

abstract interface class ConversationOwnershipStore {
  /// Dueño actual de la conversación. null = nunca hubo control humano
  /// explícito → el bot es dueño por defecto.
  ConversationOwnership? ownershipFor(String conversationId);

  /// Declara el control: humano toma la conversación o la devuelve al bot.
  /// Devuelve el estado resultante.
  ConversationOwnership setOwner(
    String conversationId,
    ConversationOwner owner, {
    int? nowMs,
  });

  /// Devuelve el control al bot (atajo de [setOwner]).
  ConversationOwnership release(String conversationId);
}

/// PERSONA-STORAGE-04 — ownership durable: cache en memoria (consultas
/// síncronas) + persistencia en la sección "ownership" de SQLite. La barrera
/// global de hidratación llama [load] antes del primer evento del pipeline.
///
/// La persistencia es fire-and-forget: si el proceso muere justo tras un
/// [setOwner], el cambio puede perderse (ownership es de bajo riesgo, a
/// diferencia del dedupe — un draft retenido perdido se redecide en el
/// siguiente turno).
final class SqliteConversationOwnershipStore
    implements ConversationOwnershipStore {
  final Map<String, ConversationOwnership> _byConversation = {};

  /// Hidratación: lee la sección y puebla la cache. Tolerante: datos
  /// corruptos se descartan (fail-open hacia bot dueño por defecto).
  Future<void> load() async {
    final raw = await AutomationDbStoreClient.instance.section('ownership');
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map || entry.key is! String) continue;
        final ownerName = value['owner'];
        final updatedAtMs = value['updatedAtMs'];
        if (ownerName is! String || updatedAtMs is! int) continue;
        final owner = _parseOwner(ownerName);
        if (owner == null) continue;
        _byConversation[entry.key as String] = ConversationOwnership(
          conversationId: entry.key as String,
          owner: owner,
          updatedAtMs: updatedAtMs,
        );
      }
    } on Object catch (error) {
      debugPrint('[ownership] hidratación falló: $error');
    }
  }

  @override
  ConversationOwnership? ownershipFor(String conversationId) =>
      _byConversation[conversationId];

  @override
  ConversationOwnership setOwner(
    String conversationId,
    ConversationOwner owner, {
    int? nowMs,
  }) {
    final ownership = ConversationOwnership(
      conversationId: conversationId,
      owner: owner,
      updatedAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _byConversation[conversationId] = ownership;
    unawaited(_persist());
    return ownership;
  }

  @override
  ConversationOwnership release(String conversationId) =>
      setOwner(conversationId, ConversationOwner.bot);

  Future<void> _persist() async {
    final json = jsonEncode({
      for (final entry in _byConversation.entries)
        entry.key: {
          'owner': entry.value.owner.name,
          'updatedAtMs': entry.value.updatedAtMs,
        },
    });
    final ok = await AutomationDbStoreClient.instance.putSection(
      'ownership',
      json,
    );
    if (!ok) debugPrint('[ownership] persistencia rechazada por el store');
  }

  static ConversationOwner? _parseOwner(String name) {
    for (final owner in ConversationOwner.values) {
      if (owner.name == name) return owner;
    }
    return null;
  }
}
