/// QUÉ: recupera evidencia durable del scope activo antes de redactar.
/// CÓMO: combina la ventana SQL reciente con memoria en RAM, sin escribir datos.
/// POR QUÉ: un snapshot incompleto al reiniciar no debe ocultar el relato original.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import '../notifications/notification_object.dart';
import '../storage/automation_db_store_client.dart';
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
    // El scope procede de la asignación existente; nunca se busca por nombre.
    if (direct == null ||
        direct.scopeId.isEmpty ||
        store is! SqliteConversationMemoryStore) {
      return memory;
    }
    // La lectura no debe bloquear una respuesta si el canal deja de contestar.
    final rows = await AutomationDbStoreClient.instance
        .listConversationMessages(scopeId: direct.scopeId, limit: 60)
        .timeout(const Duration(seconds: 3), onTimeout: () => []);
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
      scopeId: direct.scopeId,
      agentId: direct.agentId,
      entries: List.unmodifiable(entries),
      lastAtMs: entries.isEmpty ? 0 : entries.last.atMs,
      unresolvedObligations: direct.unresolvedObligations,
      activeTopic: direct.activeTopic,
      lastManualInterventionMs: direct.lastManualInterventionMs,
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
