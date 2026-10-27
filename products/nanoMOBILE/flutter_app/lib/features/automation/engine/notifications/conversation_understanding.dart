/// QUÉ HACE:
/// Estructura y tipifica la comprensión del mensaje entrante emitida por el LLM,
/// conservando preguntas y obligaciones que el modelo realmente haya declarado.
/// CÓMO FUNCIONA:
/// Decodifica JSON estructurado tolerando truncamiento de tokens y formatos legacy.
/// Desglosa intenciones, preguntas, hechos faltantes, variantes de respuesta y
/// sintetiza el estado de cobertura de cada obligación de turno.
///
/// POR QUÉ:
/// Permite revisar cobertura; parsear JSON no demuestra comprensión semántica.
library;

import 'dart:convert';
import 'conversation_obligation.dart';
import 'conversation_understanding_recovery.dart';

export 'conversation_obligation.dart';

/// Comprensión estructurada del turno conversacional.
final class ConversationUnderstanding {
  /// Intención principal detectada en el mensaje.
  final String intent;

  /// Relación con la conversación previa ('nuevo', 'continua', 'responde', 'corrige').
  final String relation;

  /// Variantes alternativas de respuesta breve y natural.
  final List<String> options;

  /// Preguntas semánticas explícitas o implícitas extraídas del mensaje.
  final List<String> questions;

  /// Hechos requeridos ausentes del contexto que impiden responder con certeza.
  final List<String> missingFacts;

  /// Obligaciones atómicas desglosadas (disponibilidad, precio, envío, etc.).
  final List<TurnObligation> obligations;

  /// Indica si responder con verdad requiere invocar una acción o consulta viva.
  final bool requiresAction;

  /// Texto propuesto para enviar al interlocutor.
  final String reply;

  const ConversationUnderstanding({
    this.intent = '',
    this.relation = '',
    this.options = const [],
    this.questions = const [],
    this.missingFacts = const [],
    this.obligations = const [],
    this.requiresAction = false,
    this.reply = '',
  });

  /// True si el turno produjo una respuesta textual concreta.
  bool get hasReply => reply.isNotEmpty;

  /// Determina si todas las obligaciones atómicas del turno fueron satisfechas o aclaradas.
  bool get allObligationsCovered =>
      obligations.isEmpty || obligations.every((o) => o.isCovered);

  /// Cantidad de obligaciones atendidas en la respuesta actual.
  int get coveredObligationCount =>
      obligations.where((o) => o.isCovered).length;

  /// Conserva la comprensión y exige revisión antes de cualquier envío.
  ConversationUnderstanding withRequiredAction() => requiresAction
      ? this
      : ConversationUnderstanding(
          intent: intent,
          relation: relation,
          options: options,
          questions: questions,
          missingFacts: missingFacts,
          obligations: obligations,
          requiresAction: true,
          reply: reply,
        );

  /// Devuelve una nueva instancia con la lista de opciones de respuesta validada.
  ConversationUnderstanding withOptions(List<String> newOptions) =>
      ConversationUnderstanding(
        intent: intent,
        relation: relation,
        options: newOptions,
        questions: questions,
        missingFacts: missingFacts,
        obligations: obligations,
        requiresAction: requiresAction,
        reply: reply,
      );


  /// Construye la instancia desde JSON tolerando tipos heterogéneos.
  factory ConversationUnderstanding.fromJson(Map<String, dynamic> json) {
    List<String> parseStrings(Object? raw) => [
      for (final v in raw is List ? raw : const <dynamic>[])
        if (v is String && v.trim().isNotEmpty) v.trim(),
    ];

    final rawObligations = json['obligations'];
    final parsedObligations = <TurnObligation>[
      if (rawObligations is List)
        for (final item in rawObligations)
          if (item is Map)
            TurnObligation.fromJson(item.cast<String, dynamic>()),
    ];

    final questions = parseStrings(json['questions']);
    final missingFacts = parseStrings(json['missingFacts']);
    final reply = cleanReplyText((json['reply'] as String?) ?? '');

    final finalObligations = parsedObligations.isNotEmpty
        ? parsedObligations
        // Sin cobertura explícita no se da una pregunta por respondida solo
        // porque la salida contenga números, un «sí» o cualquier texto.
        : [
            for (final question in questions)
              TurnObligation(topic: question, kind: ObligationKind.information),
          ];

    return ConversationUnderstanding(
      intent: (json['intent'] as String?)?.trim() ?? '',
      relation: (json['relation'] as String?)?.trim() ?? '',
      options: parseStrings(json['options'] ?? json['suggestions']),
      questions: questions,
      missingFacts: missingFacts,
      obligations: finalObligations,
      requiresAction: json['requiresAction'] == true,
      reply: reply,
    );
  }
}

/// Parsea la salida del modelo a un [ConversationUnderstanding] estructurado.
ConversationUnderstanding? parseConversationUnderstanding(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final full = _tryFullJson(trimmed);
  if (full != null) return full;

  final recovered = recoverReplyFromJson(trimmed);
  // Un JSON cortado puede haber perdido requiresAction u obligaciones.
  // Recuperar el texto sirve de borrador, nunca de autorización automática.
  if (recovered != null) {
    return ConversationUnderstanding(
      reply: recovered,
      intent: 'incomplete_model_output',
      requiresAction: true,
    );
  }

  final legacy = legacyMarkerReply(trimmed);
  if (legacy != null) return ConversationUnderstanding(reply: legacy);

  return null;
}

String parseConversationReply(String raw) =>
    parseConversationUnderstanding(raw)?.reply ?? '';

ConversationUnderstanding? _tryFullJson(String trimmed) {
  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(trimmed.substring(start, end + 1));
    if (decoded is Map) {
      final understanding = ConversationUnderstanding.fromJson(
        decoded.cast<String, dynamic>(),
      );
      if (understanding.intent.isNotEmpty ||
          understanding.hasReply ||
          understanding.obligations.isNotEmpty) {
        return understanding;
      }
    }
  } on Object catch (_) {}
  return null;
}
