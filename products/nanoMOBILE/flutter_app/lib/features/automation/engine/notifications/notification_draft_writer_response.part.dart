part of 'notification_draft_writer.dart';

// QUÉ HACE: Extrae el reply estructurado y rechaza salidas vacías o excesivas.
// CÓMO FUNCIONA: Analiza el JSON y registra solo resultados estructurales.
// POR QUÉ: El agente valida el reply sin copiar mensajes privados a Logcat.
NotificationDraftResult? _parseDraftOutput(
  String raw,
  NotificationObject notification,
  String conversationId, {
  bool allowPlainText = false,
}) {
  // Qwen no-thinking puede anteponer un bloque vacío. No contiene razonamiento
  // ni turnos inventados: solo se retira ese prefijo completo y vacío.
  final response = raw.replaceFirst(RegExp(r'^\s*<think>\s*</think>\s*'), '');
  // QUÉ: bloquea salidas con protocolo interno o diálogos inventados del modelo.
  // CÓMO: rechaza delimitadores conocidos, incluso im_end sin cierre final.
  // POR QUÉ: quitar etiquetas solamente dejaría texto alucinado listo para enviar.
  if (RegExp(
    r'<\|(?:im_start|im_end|start_header_id|end_header_id|eot_id|end_of_text)|'
    r'<(?:start_of_turn|end_of_turn|/?think)|<｜(?:begin|end)▁of▁sentence|'
    r'^\s*(?:assistant|user|system)\s*(?:\r?\n|:)',
  ).hasMatch(response)) {
    debugPrint('[draft] output rejected: leaked chat protocol');
    return null;
  }
  // PERSONA-CORE-01 — el entendimiento COMPLETO viaja con el reply:
  // el DecisionEngine consume intent/requiresAction/missingFacts (antes
  // se descartaban aquí y la decisión quedaba ciega).
  // Personal simple admite texto natural aun sin "Respuesta:". No rescata JSON
  // defectuoso ni metadatos: ventas/estado vivo siguen exigiendo su contrato.
  final parsed = parseConversationUnderstanding(response);
  final plain = response.trim();
  final canUsePlain =
      allowPlainText &&
      !RegExp(r'[{}]|"(?:reply|intent|requiresAction)"\s*:').hasMatch(plain);
  final understanding =
      parsed ?? (canUsePlain ? ConversationUnderstanding(reply: plain) : null);
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
