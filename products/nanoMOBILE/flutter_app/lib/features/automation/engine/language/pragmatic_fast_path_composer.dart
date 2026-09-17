part of 'pragmatic_fast_path.dart';

/// Compositor de respuestas para intenciones específicas (actividad, entrenamiento, día, ayuda, tiempo).
/// Cumple SOLID y límite de < 300 líneas.
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
    // Caso 1: Pregunta recíproca pura de bienestar ("bien y tú", "bien y vos", "todo bien y tú?")
    if (intents.contains(ConversationIntent.reciprocalQuestion) ||
        (intents.contains(ConversationIntent.userWellbeing) &&
            (normalized.contains('y tu') || normalized.contains('y vos')))) {
      const candidates = [
        'Bien, gracias a Dios.',
        'Todo bien, gracias a Dios.',
        'Bien también, todo tranquilo.',
        'Bien también, gracias a Dios.',
        'Bien por ahora.',
        'Todo bien por acá, tranquilo.',
        'Bien por acá, todo en orden.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 1B: Bienestar del usuario + pregunta de actividad
    if (intents.contains(ConversationIntent.userWellbeing) &&
        intents.contains(ConversationIntent.askActivity)) {
      const candidates = [
        'Qué bueno. Aquí haciendo unas cosas.',
        'Me alegra. Aquí trabajando un rato.',
        'Qué bien. Nada, aquí tranquilo.',
        'Qué bueno. Aquí en la casa.',
        'Me alegra. Por acá en lo mío.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 1C: Rap / Freestyle / Rimas
    if (intents.contains(ConversationIntent.askRap)) {
      const candidates = [
        'Sí, quiero ir a rapear.',
        'Quiero ir a rapear un rato.',
        'Sí, vamos a rapear.',
        'Puede ser, hace rato no rapeo.',
        'Quiero tirar unas rimas.',
        'De una, vamos a rapear.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 1D: Invitación directa a planes / salir
    if (intents.contains(ConversationIntent.invitation)) {
      const candidates = [
        'Sí, vamos.',
        '¿Vamos?',
        'Sí, hagámosle.',
        'Dale, vamos.',
        'Puede ser, ¿a qué hora?',
        'Listo, vamos.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 1E: Aclaración o reaseguro de bienestar ("ya te dije que estoy bien", "te dije que bien")
    if (intents.contains(ConversationIntent.wellbeingClarification)) {
      const candidates = [
        'Ah bueno jaja.',
        'Ah listo jaja.',
        'Jaja bueno, qué bien.',
        'Ah bueno, todo bien.',
        'Listo pues jaja.',
        'Jaja qué bien.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 1F: Declaración pura de bienestar del interlocutor ("bien", "todo bien", "estoy bien")
    if (intents.contains(ConversationIntent.userWellbeing)) {
      const candidates = [
        'Qué bueno.',
        'Me alegra.',
        'Qué bien.',
        'Ah bueno, me alegra.',
        'Qué bueno, todo bien.',
        'Me alegra mucho.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 2: Pregunta compuesta con entrenamiento
    if (intents.contains(ConversationIntent.askTraining)) {
      if (intents.contains(ConversationIntent.greeting) ||
          intents.contains(ConversationIntent.askDay) ||
          intents.contains(ConversationIntent.askWellbeing)) {
        if (!recentlyGreeted) {
          const candidates = [
            'Hola. Todo bien por acá, el día va tranquilo. Aún no sé seguro si entreno hoy.',
            'Hola, todo en orden. Todavía no sé seguro lo del entreno de hoy.',
            'Buenas. Por acá todo bien, tranquilo.',
          ];
          return _selectCandidate(candidates, conversationId, lastOutboundText);
        } else {
          const candidates = [
            'Todo bien por acá, el día va tranquilo.',
            'Todo en orden por acá.',
            'Por acá todo bien, tranquilo.',
          ];
          return _selectCandidate(candidates, conversationId, lastOutboundText);
        }
      } else {
        const candidates = [
          'Aún no sé seguro si voy a entrenar hoy, más tarde confirmo.',
          'Por ahora no estoy seguro del entreno de hoy.',
          'Aún no sé si entreno hoy, más tarde miro.',
          'Aún no sé, más tarde confirmo.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 3: Pregunta sobre el día ("qué tal va tu día", "cómo va tu día")
    if (intents.contains(ConversationIntent.askDay)) {
      if (intents.contains(ConversationIntent.greeting) && !recentlyGreeted) {
        const candidates = [
          'Hola, el día va bien y tranquilo por acá.',
          'Hola. Todo bien por acá, el día va marchando bien.',
          'Buenas. Por acá el día va bien.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          'El día va bien y tranquilo por acá.',
          'Todo bien por acá, el día va marchando bien.',
          'Va bien por acá, tranquilo.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 4: Pregunta sobre actividad ("qué haces", "en qué andas", "qué harás", etc.)
    if (intents.contains(ConversationIntent.askActivity)) {
      if (normalized.contains('salir') ||
          normalized.contains('en la noche') ||
          normalized.contains('sale hoy') ||
          normalized.contains('vas a ir') ||
          normalized.contains('vas ir')) {
        const candidates = [
          'Tal vez vaya, aún no sé.',
          'Creo que sí voy.',
          'Si puedo voy.',
          'Puede que vaya más tarde.',
          'Voy a ver qué hago.',
          'Hoy estoy algo ocupado, más tarde te aviso.',
          'Aún no sé seguro, más tarde te confirmo.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }

      if (normalized.contains('que haras') ||
          normalized.contains('haras hoy') ||
          normalized.contains('que haran') ||
          normalized.contains('que vas a hacer') ||
          normalized.contains('que vas hacer') ||
          normalized.contains('vas hacer') ||
          normalized.contains('vas a hacer') ||
          normalized.contains('que planes') ||
          normalized.contains('tienes pensado')) {
        const candidates = [
          'Nada, por ahora aquí tranquilo en la casa.',
          'Por ahora nada especial, aquí en la casa.',
          'Aquí haciendo unas cosas.',
          'Por acá trabajando en unas cosas.',
          'Nada raro, por ahora aquí tranquilo.',
          'Voy a ver qué hago más tarde.',
          'Aún no sé, por ahora aquí en la casa.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }

      final withWellbeing = intents.contains(ConversationIntent.askWellbeing);
      if (intents.contains(ConversationIntent.greeting) && !recentlyGreeted) {
        final candidates = withWellbeing
            ? [
                'Hola, bien, gracias a Dios. Aquí en el celular viendo memes.',
                'Hola, bien, gracias a Dios. Haciendo algo de programación.',
                'Hola. Bien, aquí molestando en el computador.',
                'Hola. Estoy bien, aquí en la casa tranquilo.',
                'Buenas. Todo bien, aquí en cama descansando.',
                'Hola, bien, gracias a Dios. Voy a comer, ¿y tú?',
              ]
            : [
                'Hola. Aquí en el celular viendo memes.',
                'Hola. Haciendo algo de programación.',
                'Buenas. Nada, molestando en el computador.',
                'Hola. Estoy en la casa.',
                'Hola. Estoy en cama descansando.',
                'Hola. Voy a comer, ¿y tú?',
              ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        final candidates = withWellbeing
            ? [
                'Bien, gracias a Dios. Aquí en el celular viendo memes.',
                'Bien, gracias a Dios. Haciendo algo de programación.',
                'Todo bien. Nada, molestando en el computador.',
                'Estoy bien. Aquí en cama descansando.',
                'Bien por ahora. Estoy en la casa tranquilo.',
                'Bien, gracias a Dios. Voy a comer, ¿y tú?',
              ]
            : [
                'Aquí en el celular viendo memes.',
                'Estoy haciendo algo de programación.',
                'Nada, molestando en el computador.',
                'Estoy en la casa.',
                'Estoy en cama.',
                'Voy a comer, ¿y tú?',
                'Aquí trabajando un rato.',
                'Nada, aquí tranquilo en la casa.',
              ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 4B: Recordatorio de compromiso / plan previo
    if (intents.contains(ConversationIntent.planReminder)) {
      const candidates = [
        'Sí, déjame revisar bien y más tarde te confirmo.',
        'Sí claro, dame un rato y te aviso seguro.',
        'Sí, déjame ver cómo me desocupo y te digo.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 4C: Pregunta sobre la hora
    if (intents.contains(ConversationIntent.askTime)) {
      final timeStr = TemporalLocationContext.formatTime(DateTime.now());
      final candidates = [
        'Son las $timeStr.',
        'Por acá son las $timeStr.',
        'Las $timeStr.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 4D: Pregunta sobre la fecha / día
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

    // Caso 4E: Pregunta sobre ubicación / ciudad
    if (intents.contains(ConversationIntent.askLocation)) {
      const candidates = [
        'Por acá en Medellín.',
        'En Medellín, Colombia.',
        'Por acá por Medellín.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 5: Pregunta de presencia ("estás ahí?", "sigues ahí?")
    if (intents.contains(ConversationIntent.askPresence)) {
      const candidates = [
        'Dime.',
        'Sí, aquí estoy.',
        'Por acá ando, cuéntame.',
        'Sí, dime.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 6: Solicitud de ayuda / tarea ("parce lo necesito para una tarea", etc.)
    if (intents.contains(ConversationIntent.askHelpOrQuestion)) {
      if (normalized.contains('tarea')) {
        const candidates = [
          'De una, cuéntame.',
          'Dale, ¿de qué es la tarea?',
          'De una, dime de qué se trata.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
      const candidates = [
        'Dime.',
        'De una, dime.',
        'Cuéntame.',
        'Claro, dime.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Situaciones cotidianas ampliadas (disponibilidad, comida, casa, familia, noche, música, etc.)
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
