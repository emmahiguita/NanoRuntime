part of 'pragmatic_fast_path.dart';

/// Compositor de respuestas deterministas para situaciones cotidianas ampliadas:
/// disponibilidad, comida, ubicación física, familia, descanso nocturno, música,
/// clima social, llamadas telefónicas, ausencia / "andar perdido" y opinión.
/// Cumple SOLID y límite de < 300 líneas.
extension _PragmaticFastPathSituations on PragmaticFastPath {
  ({String reply, List<String> suggestions})? _composeSituationalReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required String conversationId,
    required String? lastOutboundText,
  }) {
    // Situación 1: Disponibilidad / Ocupación
    if (intents.contains(ConversationIntent.askAvailability)) {
      const candidates = [
        'Ahora estoy algo ocupado, cuéntame.',
        'Estoy ocupado con unas cosas, ¿qué pasó?',
        'Dime, tengo un momento.',
        'Estoy un poco ocupado, más tarde hablamos bien.',
        'Por acá ando algo ocupado, dime.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 2: Alimentación / Comida
    if (intents.contains(ConversationIntent.askFood)) {
      if (normalized.contains('almorz')) {
        const candidates = [
          'Sí, ya almorcé.',
          'Ya almorcé hace un rato.',
          'Aún no, en esas ando.',
          'Todavía no, más tarde almuerzo.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
      if (normalized.contains('cen')) {
        const candidates = [
          'Sí, ya cené.',
          'Ya comí algo hace un rato.',
          'Aún no, más tarde ceno.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
      const candidates = [
        'Sí, ya comí.',
        'Ya comí hace un rato.',
        'Aún no, en esas ando.',
        'Todavía no, más tarde como algo.',
        'Sí, todo bien por ese lado.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 3: Ubicación física / Casa
    if (intents.contains(ConversationIntent.askPhysicalLocation)) {
      const candidates = [
        'Aquí en la casa.',
        'Por acá en la casa, tranquilo.',
        'En la casa, ¿qué pasó?',
        'Por acá en la casa, cuéntame.',
        'En la casa, todo bien.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 4: Bienestar de la familia / Entorno
    if (intents.contains(ConversationIntent.askFamily)) {
      const candidates = [
        'Todo bien por acá, gracias a Dios.',
        'Todos bien por acá, gracias por preguntar.',
        'Todo en orden en la casa, gracias a Dios.',
        'Bien, gracias a Dios, todos bien.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 5: Descanso / Noche / Sueño
    if (intents.contains(ConversationIntent.askSleep)) {
      const candidates = [
        'Sí, ya casi me voy a dormir.',
        'Por acá todavía despierto, haciendo unas cosas.',
        'Sí, ya me va a dar sueño.',
        'Aquí terminando algo y ya me acuesto.',
        'Aún despierto por acá, tranquilo.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 6: Música / Beats / Instrumentales
    if (intents.contains(ConversationIntent.askMusic)) {
      const candidates = [
        'Por acá escuchando un rap tranquilo.',
        'Un poco de música variada para concentrarme.',
        'Escuchando unas instrumentales por acá.',
        'Un poco de todo por acá.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 7: Clima cotidiano
    if (intents.contains(ConversationIntent.askWeatherSocial)) {
      const candidates = [
        'Por acá está fresco el clima.',
        'Por acá todo tranquilo con el clima.',
        'Un poco nublado por acá.',
        'Por acá normal, clima tranquilo.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 8: Solicitud de llamada telefónica
    if (intents.contains(ConversationIntent.askCall)) {
      const candidates = [
        'Por ahora mejor por mensaje, estoy algo ocupado.',
        'Escríbeme por acá mejor, dime.',
        'Ahora no puedo llamada, cuéntame por acá.',
        'Más tarde si algo me marcas, ahora ando ocupado.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 9: Ausencia / "Andas perdido"
    if (intents.contains(ConversationIntent.askLostOrMissing)) {
      const candidates = [
        'Aquí ando, ocupado con unas cosas.',
        'Jaja nada, aquí en lo mío, cuéntame.',
        'Por acá sigo, ocupado trabajando.',
        'Jaja por aquí en la casa, ¿qué cuentas?',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situación 10: Opinión / Visto bueno
    if (intents.contains(ConversationIntent.askOpinionSocial)) {
      const candidates = [
        'Se ve bien, me gusta.',
        'Está bueno, me parece que queda bien.',
        'Se ve bacano.',
        'Me parece que está bien así.',
        'Sí, aguanta bastante.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    return null;
  }
}
