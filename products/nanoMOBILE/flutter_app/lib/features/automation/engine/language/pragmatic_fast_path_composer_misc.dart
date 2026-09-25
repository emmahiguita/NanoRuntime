part of 'pragmatic_fast_path.dart';

/// Compositor auxiliar para casos de tiempo, fecha, ubicación, presencia y ayuda (< 70 LOC).
///
/// **QUÉ HACE:**
/// Resuelve consultas deterministas sobre la hora del sistema, fecha calendárica,
/// ubicación estática, preguntas de disponibilidad ('estás?') y solicitudes de ayuda/tarea.
///
/// **CÓMO FUNCIONA:**
/// Invoca TemporalLocationContext y selecciona candidatos de pragmatic_fast_path_misc_banks.dart.
///
/// **POR QUÉ:**
/// Desacopla la lógica de consultas utilitarias del compositor conversacional principal (< 200 LOC).
extension _PragmaticFastPathComposerMisc on PragmaticFastPath {
  ({String reply, List<String> suggestions})? _composeMiscReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required String conversationId,
    required String? lastOutboundText,
  }) {
    if (intents.contains(ConversationIntent.planReminder)) {
      return _selectCandidate(planReminderCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askTime)) {
      final timeStr = TemporalLocationContext.formatTime(DateTime.now());
      final candidates = [
        'Son las $timeStr.',
        'Por acá son las $timeStr.',
        'Las $timeStr.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askDate)) {
      final now = DateTime.now();
      final dayName = TemporalLocationContext.dayOfWeekSpanish(now.weekday);
      final monthName = TemporalLocationContext.monthSpanish(now.month);
      final candidates = [
        'Hoy es $dayName, ${now.day} de $monthName.',
        'Hoy es $dayName.',
        'Estamos a ${now.day} de $monthName.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askLocation)) {
      return _selectCandidate(locationCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askPresence) &&
        !intents.contains(ConversationIntent.askPhysicalLocation)) {
      return _selectCandidate(presenceCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askHelpOrQuestion)) {
      final candidates = normalized.contains('tarea')
          ? helpTaskCandidates
          : helpGeneralCandidates;
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    return null;
  }
}
