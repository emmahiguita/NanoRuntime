/// QUÉ: recupera evidencia durable del scope activo o canónico antes de redactar.
/// CÓMO: prioriza la ventana canónica; usa SQL/RAM legacy solo como respaldo.
/// POR QUÉ: no mezcla evidencia antigua con la fuente que gobierna el prompt.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import '../notifications/notification_object.dart';
import '../storage/automation_db_store_client.dart';
import 'canonical_prompt_memory.dart';
import 'conversation_context_resolver.dart';
import 'conversation_evidence_window.dart';
import 'conversation_memory.dart';
import 'incoming_message.dart';
import 'prompt_history_quality.dart';

abstract final class ConversationDurableContext {
  static Future<ConversationMemory?> resolve({
    required ConversationMemoryStore? store,
    required String conversationId,
    required NotificationObject notification,
  }) async {
    final direct = store?.memoryFor(conversationId);
    // Una sola lectura canónica por resolución. También una ventana vacía por
    // cuarentena es autoritativa: nunca la rellena con los registros rechazados.
    final canonical = await CanonicalPromptMemory.load(
      conversationId: conversationId,
      notification: notification,
      previous: direct,
    );
    if (canonical != null) return canonical;
    // No recorre todos los scopes en RAM cuando la lectura canónica funciona.
    final memory = ConversationContextResolver.resolve(
      store: store,
      conversationId: conversationId,
      notification: notification,
    );
    List<Map<String, dynamic>> rows = const [];

    // 1. Intento de lectura vía scope asignado en SQLite
    if (direct != null &&
        direct.scopeId.isNotEmpty &&
        store is SqliteConversationMemoryStore) {
      try {
        rows = await AutomationDbStoreClient.instance
            .listConversationMessages(scopeId: direct.scopeId, limit: 60)
            .timeout(const Duration(milliseconds: 1200), onTimeout: () => []);
      } on Object catch (error) {
        // Un fallo del respaldo SQL conserva la RAM; no aborta la respuesta.
        debugPrint('[ctx:durable] fallback=${error.runtimeType}');
      }
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
      entries: List.unmodifiable(PromptHistoryQuality.filter(entries)),
      lastAtMs: entries.isEmpty ? 0 : entries.last.atMs,
      unresolvedObligations:
          direct?.unresolvedObligations ??
          memory?.unresolvedObligations ??
          const [],
      activeTopic: direct?.activeTopic ?? memory?.activeTopic,
      lastManualInterventionMs:
          direct?.lastManualInterventionMs ??
          memory?.lastManualInterventionMs ??
          0,
      historyNotice:
          'Historial canónico no disponible o vacío: respaldo local parcial. '
          'No supongas continuidad ni mensajes ausentes.',
    );
  }

  // Un estado SQL no confirmado no se convierte en envío verificado.
  static ConversationMemoryEntry? _entry(Map<String, dynamic> row) {
    final kind = switch ((row['direction'], row['deliveryState'])) {
      ('inbound', 'observed') => ConversationMemoryEntryKind.inbound,
      ('outbound', 'verified') => ConversationMemoryEntryKind.outboundVerified,
      ('outbound', 'manual' || 'observed') =>
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
