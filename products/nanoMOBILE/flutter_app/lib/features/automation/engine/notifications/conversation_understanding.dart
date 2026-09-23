/// QUÉ HACE:
/// Estructura y tipifica la comprensión del mensaje entrante emitida por el LLM,
/// garantizando que todas las obligaciones conversacionales se atiendan o aclaren.
///
/// CÓMO FUNCIONA:
/// Decodifica JSON estructurado tolerando truncamiento de tokens y formatos legacy.
/// Desglosa intenciones, preguntas, hechos faltantes, variantes de respuesta y
/// sintetiza el estado de cobertura de cada obligación de turno.
///
/// POR QUÉ:
/// Evita que Nano responda solo una parte de un mensaje multitema (ej: precio sin
/// aclarar envío) o ignore preguntas compuestas de los usuarios.
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
  int get coveredObligationCount => obligations.where((o) => o.isCovered).length;

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
          if (item is Map) TurnObligation.fromJson(item.cast<String, dynamic>()),
    ];

    final questions = parseStrings(json['questions']);
    final missingFacts = parseStrings(json['missingFacts']);
    final reply = cleanReplyText((json['reply'] as String?) ?? '');

    final finalObligations = parsedObligations.isNotEmpty
        ? parsedObligations
        : _synthesizeObligations(questions, missingFacts, reply);

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

List<TurnObligation> _synthesizeObligations(
  List<String> questions,
  List<String> missingFacts,
  String reply,
) {
  if (questions.isEmpty) return const [];
  final replyLower = reply.toLowerCase();
  final missingLower = missingFacts.join(' ').toLowerCase();

  return questions.map((q) {
    final qLower = q.toLowerCase();
    var kind = ObligationKind.information;
    if (qLower.contains('precio') || qLower.contains('cuanto') || qLower.contains('vale') || qLower.contains('cuesta')) {
      kind = ObligationKind.pricing;
    } else if (qLower.contains('envio') || qLower.contains('mandar') || qLower.contains('llevar') || qLower.contains('entrega')) {
      kind = ObligationKind.logistics;
    } else if (qLower.contains('tienen') || qLower.contains('hay') || qLower.contains('disponible') || qLower.contains('queda')) {
      kind = ObligationKind.availability;
    }

    var status = ObligationStatus.pending;
    if (kind == ObligationKind.pricing && (replyLower.contains('\$') || RegExp(r'\d+').hasMatch(replyLower))) {
      status = ObligationStatus.answered;
    } else if (kind == ObligationKind.availability && (replyLower.contains('si') || replyLower.contains('disponible') || replyLower.contains('tenemos'))) {
      status = ObligationStatus.answered;
    } else if (missingLower.contains('envio') || missingLower.contains('entrega') || replyLower.contains('?')) {
      status = ObligationStatus.clarifying;
    } else if (reply.isNotEmpty) {
      status = ObligationStatus.answered;
    }

    return TurnObligation(
      topic: q,
      kind: kind,
      status: status,
    );
  }).toList();
}

/// Parsea la salida del modelo a un [ConversationUnderstanding] estructurado.
ConversationUnderstanding? parseConversationUnderstanding(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final full = _tryFullJson(trimmed);
  if (full != null) return full;

  final recovered = recoverReplyFromJson(trimmed);
  if (recovered != null) return ConversationUnderstanding(reply: recovered);

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
