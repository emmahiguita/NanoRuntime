part of 'pragmatic_fast_path.dart';

/// Plantillas de respuesta social y de sistema para PragmaticFastPath (< 120 LOC).
///
/// **QUÉ HACE:**
/// Mapea intenciones sociales y de hardware (bienestar, saludos, gratitud,
/// despedidas, risas, afirmación, negación y nivel de batería).
///
/// **CÓMO FUNCIONA:**
/// Consulta el set de intenciones y devuelve el candidato seleccionado según el contexto
/// desde los bancos de pragmatic_fast_path_template_banks.dart.
///
/// **POR QUÉ:**
/// Centraliza los bancos de frases de cortesía y estado sin sobrecargar la inferencia de lenguaje.
extension _PragmaticFastPathTemplates on PragmaticFastPath {
  ({String reply, List<String> suggestions})? _composeSocialOrSystemReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required String conversationId,
    required bool recentlyGreeted,
    required String? lastOutboundText,
    DeviceMetricsData? metrics,
  }) {
    if (intents.contains(ConversationIntent.askWellbeing)) {
      final candidates = recentlyGreeted
          ? wellbeingRecentlyGreetedCandidates
          : wellbeingStandardCandidates;
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.greeting)) {
      final candidates = recentlyGreeted
          ? greetingRecentlyGreetedCandidates
          : greetingStandardCandidates;
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.thanks)) {
      return _selectCandidate(thanksCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.farewell)) {
      if (normalized.contains('descans') ||
          normalized.contains('feliz noche') ||
          normalized.contains('buenas noches')) {
        return _selectCandidate(farewellNightCandidates, conversationId, lastOutboundText);
      }
      if (normalized.contains('manana')) {
        return _selectCandidate(farewellTomorrowCandidates, conversationId, lastOutboundText);
      }
      if (normalized.contains('tarde')) {
        return _selectCandidate(farewellAfternoonCandidates, conversationId, lastOutboundText);
      }
      return _selectCandidate(farewellGeneralCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.laughter)) {
      return _selectCandidate(laughterCandidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.affirmation) ||
        normalized == 'exacto' ||
        normalized == 'tal cual' ||
        normalized == 'literal') {
      const candidates = [
        'Sí.', 'Sí, claro.', 'Sí, puede ser.', 'Sí, de una.', 'Sí, hagámosle.',
        'Sí, vamos.', 'Sí, creo que sí.', 'Dale.', 'Listo.', 'Hagámosle.',
        'Me parece bien.', 'Sí, me sirve.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.negation)) {
      const candidates = [
        'No.', 'No creo.', 'Creo que no.', 'No, hoy no.', 'No puedo hoy.',
        'No sé si pueda.', 'Por ahora no.', 'Hoy no creo.', 'Tal vez otro día.',
        'Hoy estoy ocupado.', 'No creo que pueda.', 'Mejor después.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    if (intents.contains(ConversationIntent.askDeviceBattery)) {
      final pct = metrics?.batteryPct.round() ?? -1;
      final charging = metrics?.isCharging ?? false;
      if (pct >= 0) {
        final withGreeting =
            intents.contains(ConversationIntent.greeting) && !recentlyGreeted;
        if (charging) {
          final reply = withGreeting
              ? '¡Hola! Tengo el $pct% y está cargando.'
              : 'Tengo el $pct% y está cargando.';
          final alt1 = 'Está en $pct% (cargando).';
          final alt2 = 'Tengo el $pct%.';
          return (reply: reply, suggestions: [reply, alt1, alt2]);
        } else {
          final reply = withGreeting
              ? '¡Hola! Tengo el $pct% de batería por ahora.'
              : 'Tengo el $pct% de batería por ahora.';
          final alt1 = 'Tengo el $pct%.';
          final alt2 = 'Por ahora está en $pct%.';
          return (reply: reply, suggestions: [reply, alt1, alt2]);
        }
      } else {
        return null;
      }
    }

    return null;
  }
}
