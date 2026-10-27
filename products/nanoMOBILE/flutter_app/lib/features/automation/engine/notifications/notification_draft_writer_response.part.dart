part of 'notification_draft_writer.dart';

/// Analiza y valida la salida generada por LiteRT-LM para producir el borrador
/// principal y su lista de opciones sugeridas.
///
/// - **QUÉ HACE:** Extrae la respuesta principal y las opciones alternativas
///   (separadas por `||` o estructuradas), bloqueando fugas de protocolo o ecos.
/// - **CÓMO FUNCIONA:** Si el modelo emite varias opciones naturales separadas
///   por `||`, toma la primera como `reply` y conserva todas en `options`.
/// - **POR QUÉ:** Así el usuario siempre dispone de opciones reales generadas
///   por el modelo para elegir con un toque en la interfaz.
NotificationDraftResult? parseNotificationDraftOutput(
  String raw,
  NotificationObject notification,
  String conversationId, {
  bool allowPlainText = false,
}) {
  final response = raw.replaceFirst(RegExp(r'^\s*<think>\s*</think>\s*'), '');
  if (RegExp(
    r'<\|(?:im_start|im_end|start_header_id|end_header_id|eot_id|end_of_text)|'
    r'<(?:start_of_turn|end_of_turn|/?think)|<｜(?:begin|end)▁of▁sentence|'
    r'^\s*(?:assistant|user|system)\s*(?:\r?\n|:)',
  ).hasMatch(response)) {
    debugPrint('[draft] output rejected: leaked chat protocol');
    return null;
  }

  final parsed = parseConversationUnderstanding(response);
  final plain = response.trim();
  final extractedOptions = _extractPlainOptions(plain);
  final primaryPlain = extractedOptions.isNotEmpty
      ? extractedOptions.first
      : plain;

  final liveUnknown =
      isLiveStateQuestion(notification.requestText) &&
      _admitsUnknownLiveFact(primaryPlain);
  final liveReciprocal =
      isLiveStateQuestion(notification.requestText) &&
      _isSafeLiveReciprocal(primaryPlain);
  final canUsePlain =
      allowPlainText &&
      !RegExp(r'[{}]|"(?:reply|intent|requiresAction)"\s*:').hasMatch(plain);
  // El parser admite lenguaje natural. La decisión posterior comprueba hechos
  // del dueño; una lista de frases de incertidumbre no define una conversación.

  final understanding =
      parsed ??
      (canUsePlain
          ? ConversationUnderstanding(
              reply: primaryPlain,
              intent: liveUnknown
                  ? 'personal_live_state_unknown'
                  : liveReciprocal
                  ? 'personal_live_state_reciprocal'
                  : 'personal_conversation',
              options: extractedOptions,
            )
          : null);
  final draft = understanding?.reply ?? '';

  if (understanding != null) {
    debugPrint(
      '[understanding] conv=${_shortId(conversationId)} '
      'intentPresent=${understanding.intent.isNotEmpty} '
      'options=${understanding.options.length} '
      'questions=${understanding.questions.length} '
      'requiresAction=${understanding.requiresAction}',
    );
  }
  if (draft.isEmpty || understanding == null) return null;

  final qualityFailure = ConversationReplyQuality.rejectionReason(
    input: notification.requestText,
    reply: draft,
  );
  if (qualityFailure != null) {
    debugPrint('[draft] output rejected: quality=$qualityFailure');
    return null;
  }
  if (!PersonalLanguagePolicy.accepts(draft)) {
    debugPrint('[draft] output rejected: non-neutral language');
    return null;
  }
  if (draft.length > 2000) {
    debugPrint('[draft] output rejected: exceeds reply length limit');
    return null;
  }

  final validOptions = understanding.options
      .where(
        (opt) =>
            opt.trim().isNotEmpty &&
            ConversationReplyQuality.rejectionReason(
                  input: notification.requestText,
                  reply: opt,
                ) ==
                null &&
            PersonalLanguagePolicy.accepts(opt),
      )
      .toList();
  final normalizedUnderstanding = validOptions.isEmpty
      ? understanding.withOptions([draft])
      : understanding.withOptions(validOptions);

  debugPrint(
    '[draft:end] conv=${_shortId(conversationId)} '
    'inputChars=${notification.text.length} replyChars=${draft.length} '
    'options=${normalizedUnderstanding.options.length}',
  );
  return NotificationDraftResult(
    understanding: normalizedUnderstanding,
    reply: draft,
  );
}

/// Divide el texto plano del modelo en hasta 3 opciones limpias y sin duplicados.
List<String> _extractPlainOptions(String plain) {
  if (plain.isEmpty) return const [];
  final rawParts = plain.contains('||') ? plain.split('||') : [plain];
  final seen = <String>{};
  final result = <String>[];
  for (final part in rawParts) {
    final cleaned = part
        .replaceFirst(
          RegExp(
            r'^\s*(?:Opci[oó]n\s*\d+\s*[:.-]|\d+[.)])\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (cleaned.isEmpty) continue;
    final key = cleaned.toLowerCase();
    if (seen.add(key)) {
      result.add(cleaned);
      if (result.length >= 3) break;
    }
  }
  return result;
}

/// Reconoce expresiones naturales de incertidumbre cuando el dato vivo no consta.
bool _admitsUnknownLiveFact(String value) {
  final folded = value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  return RegExp(
    r'\bno\s+(?:lo\s+)?se\b|\bno\s+(?:lo\s+)?tengo\s+(?:claro|definido|confirmado)\b|'
    r'\bno\s+he\s+(?:decidido|pensado|confirmado)\b|\b(?:aun|todavia)\s+no\b|'
    r'\bno\s+estoy\s+segur[oa]\b|\bno\s+(?:puedo|podria)\s+saber\b|'
    r'\bno\s+tengo\s+(?:forma\s+de\s+saber|esa\s+informacion)\b|'
    r'\bno\s+(?:tengo|cuento\s+con|dispongo\s+de)\s+(?:(?:esa|la|ninguna|suficiente)\s+)?(?:informacion|datos|detalles|evidencia)\b|'
    r'\b(?:desconozco|no\s+conozco)\s+(?:su|tu|la|mi)\s+(?:actividad|ocupacion|situacion)\b|'
    r'\bno\s+(?:me\s+)?ha\s+(?:informado|comunicado|confirmado)\b|'
    r'\bno\s+hay\s+(?:(?:esa|ninguna|suficiente)\s+)?(?:informacion|datos|evidencia)\b',
  ).hasMatch(folded);
}

/// Acepta un rebote breve como «¿Y tú?» porque no inventa actividad del dueño.
bool _isSafeLiveReciprocal(String value) {
  final folded = value
      .toLowerCase()
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[¿?¡!.,;:]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return RegExp(r'^(?:y tu|y vos|y usted)$').hasMatch(folded);
}
