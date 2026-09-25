/// PERSONA-HANDOFF-03 — store de ownership por conversación.
///
/// Contrato puro (consultas síncronas: el DecisionEngine decide en caliente):
/// PERSONA-STORAGE-04 aporta la implementación SQLite (sección "ownership",
/// mismo patrón de reemplazo atómico que dedupe/rate/memory).
library;

import 'dart:convert';

import '../../engine/messaging/conversation_identity_model.dart'
    show canonicalConversationId;
import '../../engine/storage/automation_db_store_client.dart';
import '../domain/conversation_owner.dart';

abstract interface class ConversationOwnershipStore {
  /// Dueño actual de la conversación. null = nunca hubo control humano
  /// explícito → el bot es dueño por defecto.
  ConversationOwnership? ownershipFor(String conversationId);

  /// Declara el control: humano toma la conversación o la devuelve al bot.
  /// Devuelve el estado resultante.
  Future<ConversationOwnership> setOwner(
    String conversationId,
    ConversationOwner owner, {
    int? nowMs,
  });

  /// Devuelve el control al bot (atajo de [setOwner]).
  Future<ConversationOwnership> release(String conversationId);
}

/// PERSONA-STORAGE-04 — ownership durable: cache en memoria (consultas
/// síncronas) + persistencia en la sección "ownership" de SQLite. La barrera
/// global de hidratación llama [load] antes del primer evento del pipeline.
///
/// El control humano se activa en memoria antes de esperar la escritura.
/// Devolver el control al bot requiere que la escritura haya terminado.
final class SqliteConversationOwnershipStore
    implements ConversationOwnershipStore {
  final Map<String, ConversationOwnership> _byConversation = {};

  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();
  final Map<String, int> _revisions = {};

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await AutomationDbStoreClient.instance.requiredSection(
      'ownership',
    );
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Invalid ownership store');
    final loaded = <String, ConversationOwnership>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (entry.key is! String ||
          value is! Map ||
          value['owner'] is! String ||
          value['updatedAtMs'] is! int) {
        throw const FormatException('Invalid ownership entry');
      }
      final owner = _parseOwner(value['owner'] as String);
      if (owner == null) {
        throw const FormatException('Unknown conversation owner');
      }
      final conversationId = canonicalConversationId(entry.key as String);
      if (conversationId.isEmpty) continue;
      final item = ConversationOwnership(
        conversationId: conversationId,
        owner: owner,
        updatedAtMs: value['updatedAtMs'] as int,
      );
      loaded[conversationId] = item;
    }
    _byConversation.addAll(loaded);
  }

  @override
  ConversationOwnership? ownershipFor(String conversationId) {
    final id = canonicalConversationId(conversationId);
    return id.isEmpty ? null : _byConversation[id];
  }

  @override
  Future<ConversationOwnership> setOwner(
    String conversationId,
    ConversationOwner owner, {
    int? nowMs,
  }) {
    final id = canonicalConversationId(conversationId);
    final ownership = ConversationOwnership(
      conversationId: id,
      owner: owner,
      updatedAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    if (id.isEmpty) {
      return Future.error(StateError('Conversation identity is unavailable'));
    }
    final revision = (_revisions[id] ?? 0) + 1;
    _revisions[id] = revision;

    // Tomar control humano es inmediato. Liberarlo queda cerrado hasta que
    // SQLite confirme la escritura, evitando autoenvíos tras un fallo.
    _byConversation[id] = ConversationOwnership(
      conversationId: id,
      owner: ConversationOwner.human,
      updatedAtMs: ownership.updatedAtMs,
    );

    final write = _writes.then((_) async {
      // Una revisión nueva invalida esta escritura antes de tocar el disco.
      if (_revisions[id] != revision) return;
      final snapshot = Map<String, ConversationOwnership>.of(_byConversation);
      snapshot[id] = ownership;
      final ok = await AutomationDbStoreClient.instance.putSection(
        'ownership',
        jsonEncode({
          for (final entry in snapshot.entries)
            entry.key: {
              'owner': entry.value.owner.name,
              'updatedAtMs': entry.value.updatedAtMs,
            },
        }),
      );
      if (!ok) throw StateError('Ownership persistence rejected');
      if (_revisions[id] == revision) {
        _byConversation[id] = ownership;
      }
    });
    _writes = write.catchError((Object _) {});
    return write.then((_) => _byConversation[id] ?? ownership);
  }

  @override
  Future<ConversationOwnership> release(String conversationId) =>
      setOwner(conversationId, ConversationOwner.bot);

  static ConversationOwner? _parseOwner(String name) {
    for (final owner in ConversationOwner.values) {
      if (owner.name == name) return owner;
    }
    return null;
  }
}
