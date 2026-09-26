part of 'pragmatic_fast_path.dart';

/// Compositor principal de respuestas para intenciones de diálogo (< 130 LOC).
///
/// **QUÉ HACE:**
/// Resuelve interacciones de bienestar, actividades, planes, rap e invitaciones,
/// delegando consultas auxiliares a compositores específicos.
///
/// **CÓMO FUNCIONA:**
/// Evalúa secuencialmente los casos de diálogo unificado empleando los bancos
/// constantes en pragmatic_fast_path_dialogue_banks.dart y delegando en
/// _composeActivityReply, _composeMiscReply, _composeSituationalReply
/// y _composeSocialOrSystemReply.
///
/// **POR QUÉ:**
/// Asegura una jerarquía de prioridades clara y modular bajo SOLID (< 200 líneas por archivo).
extension _PragmaticFastPathComposer on PragmaticFastPath {
  ({String reply, List<String> suggestions})? _composeUnifiedReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required Set<String> tokens,
    required String conversationId,
    required bool recentlyGreeted,
    required String? lastOutboundText,
    DeviceMetricsData? metrics,
  }) {
    // Caso 1: Pregunta recíproca pura de bienestar ("bien y tú", "bien y vos")
    if (intents.contains(ConversationIntent.reciprocalQuestion) ||
        (intents.contains(ConversationIntent.userWellbeing) &&
            (normalized.contains('y tu') || normalized.contains('y vos')))) {
      return _selectCandidate(reciprocalCandidates, conversationId, lastOutboundText);
    }

    // Caso 1B: Bienestar del interlocutor + actividad
    if (intents.contains(ConversationIntent.userWellbeing) &&
        intents.contains(ConversationIntent.askActivity)) {
      return _selectCandidate(userWellbeingActivityCandidates, conversationId, lastOutboundText);
    }

    // Caso 1C: Rap / Freestyle
    if (intents.contains(ConversationIntent.askRap)) {
      return _selectCandidate(rapCandidates, conversationId, lastOutboundText);
    }

    // Caso 1D: Invitación a planes / salir
    if (intents.contains(ConversationIntent.invitation)) {
      return _selectCandidate(invitationCandidates, conversationId, lastOutboundText);
    }

    // Caso 1E: Aclaración de bienestar ("ya te dije que bien")
    if (intents.contains(ConversationIntent.wellbeingClarification)) {
      return _selectCandidate(wellbeingClarificationCandidates, conversationId, lastOutboundText);
    }

    // Caso 1F: Declaración pura de bienestar ("bien", "todo bien")
    if (intents.contains(ConversationIntent.userWellbeing)) {
      return _selectCandidate(userWellbeingPureCandidates, conversationId, lastOutboundText);
    }

    // Caso 1G: Reaseguro social o empatía del interlocutor ("me alegra", "qué bueno")
    if (intents.contains(ConversationIntent.socialReassurance)) {
      return _selectCandidate(socialReassuranceCandidates, conversationId, lastOutboundText);
    }

    // Caso 1H: Corrección del usuario ("eso no lo pregunté yo", "te equivocaste")
    if (intents.contains(ConversationIntent.userCorrection)) {
      return _selectCandidate(safeRepairCorrectionOptions, conversationId, lastOutboundText);
    }

    // Caso 2: Pregunta compuesta con entrenamiento
    if (intents.contains(ConversationIntent.askTraining)) {
      if (intents.contains(ConversationIntent.greeting) ||
          intents.contains(ConversationIntent.askDay) ||
          intents.contains(ConversationIntent.askWellbeing)) {
        final candidates = recentlyGreeted ? trainingCandidates : trainingWithGreetingCandidates;
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        return _selectCandidate(trainingCandidates, conversationId, lastOutboundText);
      }
    }

    // Caso 3: Pregunta sobre el día
    if (intents.contains(ConversationIntent.askDay)) {
      final candidates = (intents.contains(ConversationIntent.greeting) && !recentlyGreeted)
          ? dayWithGreetingCandidates
          : dayCandidates;
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 4: Respuestas de actividad
    final activity = _composeActivityReply(
      intents: intents,
      normalized: normalized,
      conversationId: conversationId,
      recentlyGreeted: recentlyGreeted,
      lastOutboundText: lastOutboundText,
    );
    if (activity != null) return activity;

    // Caso 5: Consultas misceláneas (planes, hora, fecha, ubicación, presencia, ayuda)
    final misc = _composeMiscReply(
      intents: intents,
      normalized: normalized,
      conversationId: conversationId,
      lastOutboundText: lastOutboundText,
    );
    if (misc != null) return misc;

    // Caso 6: Situaciones cotidianas ampliadas (comida, casa, familia, noche, música, etc.)
    final situational = _composeSituationalReply(
      intents: intents,
      normalized: normalized,
      conversationId: conversationId,
      lastOutboundText: lastOutboundText,
    );
    if (situational != null) return situational;

    // Casos 7-14: Delegar a plantillas sociales y de sistema
    return _composeSocialOrSystemReply(
      intents: intents,
      normalized: normalized,
      conversationId: conversationId,
      recentlyGreeted: recentlyGreeted,
      lastOutboundText: lastOutboundText,
      metrics: metrics,
    );
  }
}
