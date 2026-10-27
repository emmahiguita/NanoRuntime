// personal_turn_selector.dart
//
// QUÉ HACE:
// Selecciona y rankea la mejor respuesta candidata entre el estilo de memoria SQLite (Emma Seeds)
// y el generador determinista FastPath, enriqueciendo el understanding conversacional.
//
// CÓMO FUNCIONA:
// 1. Agrupa las respuestas candidatas y sugerencias de styleMatch y fastMatch.
// 2. Invoca PersonalResponseSelector.selectFromPool para ponderar variabilidad y evitar repeticiones.
// 3. Reconstruye el ConversationUnderstanding preservando intenciones, preguntas y acciones.
//
// POR QUÉ:
// Aplica SOLID (SRP) aislando la lógica de combinación y selección léxica de turnos (< 90 líneas).

import '../../engine/conversation/persona_style_resolver.dart';
import '../../engine/language/pragmatic_fast_path.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/notifications/conversation_understanding.dart';
import 'personal_conversation_resolver.dart';

/// Selector y ensamblador de la mejor respuesta del turno personal.
final class PersonalTurnSelector {
  const PersonalTurnSelector();

  /// Evalúa y rankea los candidatos disponibles devolviendo el turno optimizado.
  PersonalTurnReply? selectBestCandidate({
    required String userText,
    required String conversationId,
    required ConversationMemory? memory,
    required PersonaStyleMatch? styleMatch,
    required FastPathCandidate? fastMatch,
  }) {
    if (styleMatch == null && fastMatch == null) {
      return null;
    }
    final pool = <String>[
      if (styleMatch != null) ...[styleMatch.reply, ...styleMatch.suggestions],
      if (fastMatch != null) ...[fastMatch.reply, ...fastMatch.suggestions],
    ];
    final ranked = PersonalResponseSelector.selectFromPool(
      pool: pool,
      conversationId: conversationId,
      memory: memory,
      userText: userText,
    );
    final chosenFromFast =
        fastMatch != null &&
        (ranked.reply == fastMatch.reply ||
            fastMatch.suggestions.contains(ranked.reply)) &&
        (styleMatch == null ||
            (ranked.reply != styleMatch.reply &&
                !styleMatch.suggestions.contains(ranked.reply)));
    final baseUnderstanding = chosenFromFast
        ? fastMatch.understanding
        : (styleMatch?.understanding ?? fastMatch!.understanding);
    return PersonalTurnReply(
      text: ranked.reply,
      understanding: ConversationUnderstanding(
        intent: baseUnderstanding.intent,
        relation: baseUnderstanding.relation,
        options: ranked.suggestions,
        questions: baseUnderstanding.questions,
        missingFacts: baseUnderstanding.missingFacts,
        obligations: baseUnderstanding.obligations,
        requiresAction: baseUnderstanding.requiresAction,
        reply: ranked.reply,
      ),
      suggestions: ranked.suggestions,
      isFast: true,
    );
  }
}
