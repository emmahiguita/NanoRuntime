part of 'pragmatic_fast_path.dart';

/// Plantillas de respuesta social y de sistema para PragmaticFastPath.
/// Maneja bienestar general, saludos, agradecimientos, despedidas, hardware y selección aleatoria-determinista.
/// Cumple SOLID y límite de < 300 líneas.
extension _PragmaticFastPathTemplates on PragmaticFastPath {
  ({String reply, List<String> suggestions})? _composeSocialOrSystemReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required String conversationId,
    required bool recentlyGreeted,
    required String? lastOutboundText,
    DeviceMetricsData? metrics,
  }) {
    // Caso 7: Bienestar / Saludo + Bienestar ("cómo estás", "hola cómo estás", "qué tal")
    if (intents.contains(ConversationIntent.askWellbeing)) {
      if (recentlyGreeted) {
        const candidates = [
          'Bien, gracias a Dios.',
          'Todo bien por acá, tranquilo.',
          'Bien por acá, todo en orden.',
          'Bien por ahora.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          'Bien, gracias a Dios, ¿y tú?',
          'Estoy bien, ¿y tú?',
          'Bien, gracias a Dios.',
          'Todo bien, gracias a Dios.',
          'Bien por ahora, ¿y tú?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 8: Saludo simple ("hola", "hola emma", "buenas", "oe", "ey")
    if (intents.contains(ConversationIntent.greeting)) {
      if (recentlyGreeted) {
        const candidates = [
          'Dime.',
          '¿Qué más? Cuéntame.',
          'Por acá sigo, cuéntame.',
          'Por acá en la casa, cuéntame.',
          'Hola, cuéntame.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          'Hola.',
          'Hola, ¿cómo estás?',
          'Buenas.',
          'Ey, ¿todo bien?',
          '¿Cómo vas?',
          'Hola, ¿qué haces?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 9: Agradecimiento ("gracias", "muchas gracias")
    if (intents.contains(ConversationIntent.thanks)) {
      const candidates = [
        'Con gusto.',
        'Todo bien.',
        'De nada.',
        'Tranquilo.',
        'Dale, todo bien.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 10: Despedida ("chao", "nos vemos", "descansa", "hasta mañana", "hablamos")
    if (intents.contains(ConversationIntent.farewell)) {
      if (normalized.contains('descans') ||
          normalized.contains('feliz noche') ||
          normalized.contains('buenas noches')) {
        const candidates = [
          'Dale, que descanses.',
          'Descansa pues, hablamos.',
          'Dale, feliz noche.',
          'Que descanses.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
      if (normalized.contains('manana')) {
        const candidates = [
          'Dale, hablamos mañana.',
          'Listo, hablamos mañana.',
          'Hablamos mañana, cuídate.',
          'Listo, hasta mañana.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
      if (normalized.contains('tarde')) {
        const candidates = [
          'Dale, feliz tarde.',
          'Bueno, que tengas buena tarde.',
          'Hablamos pues, cuídate.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
      const candidates = [
        'Bueno, hablamos.',
        'Hablamos luego.',
        'Dale, cuídate.',
        'Bueno, nos hablamos.',
        'Listo, hablamos después.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 11: Risa ("jajaja", "jeje", "jaja literal")
    if (intents.contains(ConversationIntent.laughter)) {
      const candidates = ['😂', 'Literal jaja', 'Jaja tal cual', 'Jajaja sí'];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 12: Afirmación ("sí", "dale", "listo", "ok", "exacto", "hagámosle")
    if (intents.contains(ConversationIntent.affirmation) ||
        normalized == 'exacto' ||
        normalized == 'tal cual' ||
        normalized == 'literal') {
      const candidates = [
        'Sí.',
        'Sí, claro.',
        'Sí, puede ser.',
        'Sí, de una.',
        'Sí, hagámosle.',
        'Sí, vamos.',
        'Sí, creo que sí.',
        'Dale.',
        'Listo.',
        'Hagámosle.',
        'Me parece bien.',
        'Sí, me sirve.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 13: Negación / Rechazar suavemente ("no", "no creo", "hoy no creo", "por ahora no")
    if (intents.contains(ConversationIntent.negation)) {
      const candidates = [
        'No.',
        'No creo.',
        'Creo que no.',
        'No, hoy no.',
        'No puedo hoy.',
        'No sé si pueda.',
        'Por ahora no.',
        'Hoy no creo.',
        'Tal vez otro día.',
        'Hoy estoy ocupado.',
        'No creo que pueda.',
        'Mejor después.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 14: Hecho de hardware bajo demanda: Batería
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

  /// Selecciona de manera determinista y temporal un candidato que no repita el último mensaje,
  /// y provee hasta 3 sugerencias alternativas del mismo conjunto.
  ({String reply, List<String> suggestions}) _selectCandidate(
    List<String> pool,
    String conversationId,
    String? lastOutboundText,
  ) {
    if (pool.isEmpty) {
      return (
        reply: 'Todo bien por acá.',
        suggestions: const ['Todo bien por acá.'],
      );
    }

    final minuteBucket = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final seed = (conversationId.hashCode ^ minuteBucket).abs();

    final available = pool
        .where((c) => c.trim() != lastOutboundText?.trim())
        .toList();
    final listToUse = available.isNotEmpty ? available : pool;

    final selected = listToUse[seed % listToUse.length];
    final suggestions = <String>[selected];
    for (final c in pool) {
      if (!suggestions.contains(c) && suggestions.length < 3) {
        suggestions.add(c);
      }
    }
    return (reply: selected, suggestions: suggestions);
  }
}
