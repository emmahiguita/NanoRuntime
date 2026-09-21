part of 'pragmatic_fast_path.dart';

/// Compositor de respuestas deterministas para situaciones cotidianas ampliadas (< 90 LOC).
///
/// **QUÉ HACE:**
/// Resuelve disponibilidad, comida, ubicación física, familia, descanso nocturno,
/// música, clima social, llamadas telefónicas, ausencia y opiniones.
///
/// **CÓMO FUNCIONA:**
/// Mapea cada ConversationIntent situacional a los bancos constantes en
/// pragmatic_fast_path_situation_banks.dart seleccionando mediante _selectCandidate.
///
/// **POR QUÉ:**
/// Cumple SOLID y mantiene la separación entre reglas de matching y catálogo léxico (< 200 LOC).
extension _PragmaticFastPathSituations on PragmaticFastPath {
  ({String reply, List<String> suggestions})? _composeSituationalReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required String conversationId,
    required String? lastOutboundText,
  }) {
    if (intents.contains(ConversationIntent.askAvailability)) {
      return _selectCandidate(availabilityCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askFood)) {
      if (normalized.contains('almorz')) {
        return _selectCandidate(lunchCandidates, conversationId, lastOutboundText);
      }
      if (normalized.contains('cen')) {
        return _selectCandidate(dinnerCandidates, conversationId, lastOutboundText);
      }
      return _selectCandidate(foodGeneralCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askPhysicalLocation)) {
      return _selectCandidate(physicalLocationCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askFamily)) {
      return _selectCandidate(familyCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askSleep)) {
      return _selectCandidate(sleepCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askMusic)) {
      return _selectCandidate(musicCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askWeatherSocial)) {
      return _selectCandidate(weatherSocialCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askCall)) {
      return _selectCandidate(callCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askLostOrMissing)) {
      return _selectCandidate(lostOrMissingCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askOpinionSocial)) {
      return _selectCandidate(opinionSocialCandidates, conversationId, lastOutboundText);
    }

    return null;
  }
}
