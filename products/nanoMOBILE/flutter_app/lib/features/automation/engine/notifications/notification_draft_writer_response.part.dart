part of 'notification_draft_writer.dart';

// QUÉ HACE: Extrae el reply estructurado y rechaza salidas vacías o excesivas.
// CÓMO FUNCIONA: Analiza el JSON y registra solo resultados estructurales.
// POR QUÉ: El agente valida el reply sin copiar mensajes privados a Logcat.
NotificationDraftResult? _parseDraftOutput(
  String raw,
  NotificationObject notification,
  String conversationId,
) {
  // PERSONA-CORE-01 — el entendimiento COMPLETO viaja con el reply:
  // el DecisionEngine consume intent/requiresAction/missingFacts (antes
  // se descartaban aquí y la decisión quedaba ciega).
  final understanding = parseConversationUnderstanding(raw);
  final draft = understanding?.reply ?? '';
  // CONV-SEM-03 — traza diagnóstica del entendimiento (temporal, como
  // [ctx:gate]): sin ella la relación declarada por el modelo era
  // invisible en logcat y los fallos de continuidad no se podían
  // verificar en dispositivo. Una línea por turno.
  if (understanding != null) {
    debugPrint(
      '[understanding] conv=${_shortId(conversationId)} '
      'intentPresent=${understanding.intent.isNotEmpty} '
      'questions=${understanding.questions.length} '
      'missingFacts=${understanding.missingFacts.length} '
      'requiresAction=${understanding.requiresAction}',
    );
    // R5-02 — traza TEMPORAL de calidad del reply (brief R5 §27; se
    // quita tras la evidencia física). echo usa la MISMA normalización
    // del dedupe (jamás una nueva); la decisión final llega después en
    // [decision] del dispatcher, aquí aún no existe.
    debugPrint(
      '[reply:quality] conv=${_shortId(conversationId)} '
      'echo=${normalizeDedupeText(draft) == normalizeDedupeText(notification.text)} '
      'questions=${understanding.questions.length} '
      'missingFacts=${understanding.missingFacts.length} '
      'liveStateRequired=${isLiveStateQuestion(notification.text)} '
      'decision=?',
    );
  }
  if (draft.isEmpty && raw.trim().isNotEmpty) {
    // Registra tamaño y resultado del parser; el contenido puede ser privado.
    debugPrint('[draft] sin reply parseable; rawChars=${raw.length}');
  }
  if (draft.isEmpty || understanding == null) return null;
  if (draft.length > 2000) {
    debugPrint('[draft] output rejected: exceeds reply length limit');
    return null;
  }
  final reply = draft;
  debugPrint(
    '[draft:end] conv=${_shortId(conversationId)} '
    'inputChars=${notification.text.length} replyChars=${reply.length}',
  );
  return NotificationDraftResult(understanding: understanding, reply: reply);
}
