/// QUÉ: recupera evidencia durable del scope activo o canónico antes de redactar.
/// CÓMO: combina la ventana SQL unificada (canonical_messages) con memoria en RAM.
/// POR QUÉ: unifica Web, Notificaciones y Meta sin depender de silos paralelos ni perder el hilo original.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import '../notifications/notification_object.dart';
import '../storage/automation_db_store_client.dart';
import 'canonical_message_store.dart';
import 'conversation_context_resolver.dart';
import 'conversation_evidence_window.dart';
import 'conversation_memory.dart';
import 'incoming_message.dart';

abstract final class ConversationDurableContext {
  static Future<ConversationMemory?> resolve({
    required ConversationMemoryStore? store,
    required String conversationId,
    required NotificationObject notification,
  }) async {
    final memory = ConversationContextResolver.resolve(
      store: store,
      conversationId: conversationId,
      notification: notification,
    );
    final direct = store?.memoryFor(conversationId);
    List<Map<String, dynamic>> rows = const [];

    // 1. Intento de lectura vía scope asignado en SQLite
    if (direct != null &&
        direct.scopeId.isNotEmpty &&
        store is SqliteConversationMemoryStore) {
      rows = await AutomationDbStoreClient.instance
          .listConversationMessages(scopeId: direct.scopeId, limit: 60)
          .timeout(const Duration(seconds: 3), onTimeout: () => []);
    }

    // 2. Si no hay filas por scopeId o es canal directo (Web/Meta), consulta la fuente canónica única
    if (rows.isEmpty) {
      try {
        final canonicalList = await canonicalMessageStore
            .list(conversationId, limit: 60)
            .timeout(const Duration(seconds: 3), onTimeout: () => []);
        if (canonicalList.isNotEmpty) {
          rows = canonicalList
              .map((m) => {
                    'direction': m.direction.name,
                    'deliveryState': m.deliveryState,
                    'body': m.body,
                    'sender': m.sender,
                    'atMs': m.occurredAtMs,
                    'eventId': m.providerMessageId.isNotEmpty
                        ? m.providerMessageId
                        : m.id,
                    'ruleId': m.rawMetadata['ruleId'] as String? ?? '',
                  })
              .toList(growable: false);
        }
      } catch (_) {}
    }

    if (rows.isEmpty && direct == null) {
      return memory;
    }

    final durable = rows.map(_entry).whereType<ConversationMemoryEntry>();
    final entries = ConversationEvidenceWindow.resolve([
      ...durable,
      ...?memory?.entries,
    ], IncomingMessage.fromNotification(notification));
    debugPrint(
      '[ctx:durable] rows=${rows.length} merged=${entries.length} '
      'snapshot=${memory?.entries.length ?? 0}',
    );
    return ConversationMemory(
      conversationId: conversationId,
      scopeId: direct?.scopeId ?? conversationId,
      agentId: direct?.agentId ?? memory?.agentId,
      entries: List.unmodifiable(entries),
      lastAtMs: entries.isEmpty ? 0 : entries.last.atMs,
      unresolvedObligations: direct?.unresolvedObligations ?? memory?.unresolvedObligations ?? const [],
      activeTopic: direct?.activeTopic ?? memory?.activeTopic,
      lastManualInterventionMs: direct?.lastManualInterventionMs ?? memory?.lastManualInterventionMs ?? 0,
    );
  }

  // Un estado SQL no confirmado no se convierte en envío verificado.
  static ConversationMemoryEntry? _entry(Map<String, dynamic> row) {
    final kind = switch ((row['direction'], row['deliveryState'])) {
      ('inbound', 'observed') => ConversationMemoryEntryKind.inbound,
      ('outbound', 'verified') => ConversationMemoryEntryKind.outboundVerified,
      ('outbound', 'manual') =>
        ConversationMemoryEntryKind.outboundObservedManual,
      ('outbound', 'dispatched') =>
        ConversationMemoryEntryKind.outboundDispatched,
      ('outbound', 'unknown') => ConversationMemoryEntryKind.effectUnknown,
      _ => null,
    };
    final text = row['body'] as String? ?? '';
    if (kind == null || text.trim().isEmpty) return null;
    return ConversationMemoryEntry(
      kind: kind,
      text: text,
      sender: row['sender'] as String? ?? '',
      atMs: (row['atMs'] as num?)?.toInt() ?? 0,
      eventId: row['eventId'] as String? ?? '',
      ruleId: row['ruleId'] as String? ?? '',
    );
  }
}
