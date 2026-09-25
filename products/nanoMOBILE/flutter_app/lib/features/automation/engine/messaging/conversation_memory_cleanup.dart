// QUÉ HACE: elimina una memoria conversacional completa sin tocar WhatsApp.
// CÓMO: retira el scope del núcleo, persiste un snapshot atómico y revierte
// el estado en memoria si SQLite rechaza la operación.
// POR QUÉ: "limpiar" debe borrar datos reales, no ocultar una tarjeta.

part of 'conversation_memory.dart';

Future<void> _clearConversationMemory(
  _MemoryCore store,
  String conversationId,
) async {
  final cleanId = conversationId.trim();
  if (cleanId.isEmpty) return;
  final scopeId = store._scopeFor(cleanId);
  final entries = store._byConversation.remove(scopeId);
  final obligations = store._obligationsByConversation.remove(scopeId);
  final topic = store._topicByConversation.remove(scopeId);
  final manualAt = store._manualAtByConversation.remove(scopeId);
  final mappedId = store._conversationIdByScope.remove(scopeId);
  final agent = store._agentByScope.remove(scopeId);

  try {
    final snapshotJson = jsonEncode(store._snapshot());
    final persisted = await store._persistConversationRemoval(
      scopeId,
      snapshotJson,
    );
    if (!persisted) throw StateError('Conversation cleanup was rejected');
  } catch (_) {
    // Rollback: conservar la memoria previa evita que la UI prometa un borrado
    // que el almacenamiento durable no pudo completar.
    if (entries != null) {
      final current = store._byConversation[scopeId] ?? const [];
      store._byConversation[scopeId] = store._deduplicateByEventId([
        ...entries,
        ...current,
      ]);
    }
    if (obligations != null) {
      store._obligationsByConversation[scopeId] = obligations;
    }
    if (topic != null) store._topicByConversation[scopeId] = topic;
    if (manualAt != null) store._manualAtByConversation[scopeId] = manualAt;
    if (mappedId != null) store._conversationIdByScope[scopeId] = mappedId;
    if (agent != null) store._agentByScope[scopeId] = agent;
    rethrow;
  }
}
