part of 'notification_draft_writer.dart';

// QUÉ HACE: Clasifica errores del motor sin registrar cuerpos de respuesta.
// CÓMO FUNCIONA: Traduce mensajes conocidos a códigos seguros para Logcat.
// POR QUÉ: La respuesta HTTP puede contener texto privado del usuario.
String _draftFailureCode(Object error) {
  if (error is! LLMEngineException) return error.runtimeType.toString();
  final message = error.message.toLowerCase();
  if (message.contains('timeout')) return 'engine_timeout';
  if (message.contains('no se pudo contactar')) return 'connection_error';
  if (message.contains('respuesta inválida')) return 'invalid_response';
  if (message.contains('límite de tokens')) return 'token_limit';
  if (message.startsWith('http ')) return 'engine_http_error';
  return 'engine_error';
}

/// CONTEXT-GATE-01 — hash corto del id de conversación para la traza.
String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

/// R5-06 — CORRECTION REPAIR: ancla de reparación para turnos de
/// corrección. El cliente corrige QUÉ DIJO Nano; sin ese ancla el modelo
/// responde "¿qué quieres que haga?" (no sabe qué corrigieron). Solo el
/// ÚLTIMO reply de Nano entra (160 chars máx): el resto del diálogo es
/// tema muerto que incita eco. Sin reply previo de Nano no hay nada que
/// reparar: historial limpio.
String _correctionAnchor(List<ConversationMemoryEntry> entries) {
  for (final e in entries.reversed) {
    if (e.kind != ConversationMemoryEntryKind.inbound) {
      final t = e.text.length <= 160 ? e.text : e.text.substring(0, 160);
      return 'Lo último que respondiste: $t';
    }
  }
  return '(sin historial previo)';
}
