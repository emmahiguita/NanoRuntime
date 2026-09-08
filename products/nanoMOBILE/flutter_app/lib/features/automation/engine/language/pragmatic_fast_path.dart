/// PragmaticFastPath (A07) — motor de diálogo pragmático y lingüístico sin LLM.
///
/// ANDROID FIRST / DETERMINISTIC SECOND / SMALL LLM LAST:
/// Comprende y resuelve turnos conversacionales cotidianos en < 5ms:
/// - Saludos simples y compuestos ("hola", "hola emma", "buenas tardes")
/// - Chequeo y estado de bienestar ("cómo estás", "qué tal", "todo bien?")
/// - Preguntas recíprocas ("bien y tú", "bien y vos", "todo bien y tú?")
/// - Preguntas de actividad / día ("qué haces", "en qué andas", "qué tal tu día")
/// - Preguntas de entreno / live state con honestidad ("vas a ir hoy a entrenar?", "entrenas hoy?")
/// - Preguntas de presencia ("estás ahí?", "sigues por ahí?")
/// - Solicitudes de ayuda o preguntas ("parce lo necesito para una tarea", "una pregunta")
/// - Multi-intentos en una sola frase integrada ("hola emma cómo estás, qué tal va tu día, vas a ir hoy a entrenar?")
/// - Agradecimientos y despedidas ("gracias", "chao", "nos vemos")
///
/// Principios estrictos de la persona de Emma:
/// - Tono auténtico, colombiano/paisa cercano ("parce", "todo bien por acá", "de una"), sin sonar robótico.
/// - CERO lenguaje de call-center ("¿En qué puedo ayudarte hoy?" está prohibido).
/// - NUNCA inventa actividades reales ni ubicaciones en vivo (declara honestamente "aún no sé seguro").
/// - Respuestas breves: entre 2 y 20 palabras, máximo 1 repregunta.
/// - Una sola respuesta unificada (no respuestas fragmentadas).
/// - Anti-repetición: rotación por ventana de tiempo y memoria factual del último envío para no repetir el mismo texto.
/// - Si ya saludó en los últimos 180 segundos, no vuelve a repetir "Hola".
/// - Seguridad: si detecta intención comercial, queja de soporte, corrección o comandos, retorna null para que actúe el catálogo o el motor de negocio.
library;

import '../../personal_agent/domain/conversation_agent_role.dart'
    show
        correctionPhrases,
        commercialIntentTokens,
        supportPhrases;
import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import '../messaging/conv_turn_state.dart'
    show ClientContextEntry, isPureGreeting;
import '../messaging/conversation_memory.dart'
    show ConversationMemory, ConversationMemoryEntryKind;
import '../notifications/conversation_understanding.dart';

/// Intento comunicativo elemental detectado en el texto.
enum ConversationIntent {
  greeting,
  askWellbeing,
  userWellbeing,
  reciprocalQuestion,
  askActivity,
  askDay,
  askTraining,
  askPresence,
  askHelpOrQuestion,
  thanks,
  farewell,
  laughter,
  affirmation,
}

final class FastPathCandidate {
  final String act;
  final String reply;
  final ConversationUnderstanding understanding;

  const FastPathCandidate({
    required this.act,
    required this.reply,
    required this.understanding,
  });
}

final class PragmaticFastPath {
  final ConversationMemory? Function(String conversationId)? memoryFor;
  final ClientContextEntry? Function(String conversationId)? contextEntryFor;
  final String? Function()? ownerName;

  const PragmaticFastPath({
    this.memoryFor,
    this.contextEntryFor,
    this.ownerName,
  });

  /// Resuelve el turno conversacional o devuelve null para escalar al LLM / catálogo.
  FastPathCandidate? resolve({
    required String text,
    required String conversationId,
  }) {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    final normalized = normalizeText(raw);
    final tokens = tokenizeText(normalized);
    if (tokens.isEmpty) return null;

    // 1. Guardias de escape estricto: Comercio, Soporte, Corrección, Comandos
    if (_hasCommercialOrCommandSignal(normalized, tokens)) {
      return null;
    }

    // 2. Extraer el conjunto de intenciones comunicativas
    final intents = _extractIntents(normalized, tokens);
    if (intents.isEmpty) return null;

    // 3. Inspeccionar historial de conversación reciente para anti-repetición
    final memory = memoryFor?.call(conversationId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    var recentlyGreeted = false;
    String? lastOutboundText;

    if (memory != null && memory.entries.isNotEmpty) {
      for (var i = memory.entries.length - 1; i >= 0; i--) {
        final entry = memory.entries[i];
        if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
            entry.kind == ConversationMemoryEntryKind.outboundDispatched) {
          lastOutboundText = entry.text;
          // Si el último envío fue hace menos de 180 segundos (3 min) y tenía saludo
          if (nowMs - entry.atMs < 180000) {
            final foldedOut = normalizeText(entry.text);
            if (foldedOut.contains('hola') ||
                foldedOut.contains('buenas') ||
                foldedOut.contains('buen dia') ||
                foldedOut.contains('hey')) {
              recentlyGreeted = true;
            }
          }
          break;
        }
      }
    }

    // 4. Componer la respuesta unificada y natural
    final reply = _composeUnifiedReply(
      intents: intents,
      normalized: normalized,
      tokens: tokens,
      conversationId: conversationId,
      recentlyGreeted: recentlyGreeted,
      lastOutboundText: lastOutboundText,
    );

    if (reply == null || reply.trim().isEmpty) return null;

    final actLabel = intents.map((i) => i.name).join('+');
    return FastPathCandidate(
      act: actLabel,
      reply: reply.trim(),
      understanding: ConversationUnderstanding(
        intent: 'personal',
        relation: 'continua',
        requiresAction: false,
        missingFacts: const [],
        questions: const [],
        reply: reply.trim(),
      ),
    );
  }

  /// Verifica si el mensaje contiene intenciones de catálogo, compra, reclamo o comando.
  bool _hasCommercialOrCommandSignal(String normalized, Set<String> tokens) {
    if (tokens.any(commercialIntentTokens.contains)) return true;
    if (supportPhrases.any(normalized.contains)) return true;
    if (correctionPhrases.any(normalized.contains)) return true;

    // Comandos de automatización / terminal
    if (normalized.startsWith('abre ') ||
        normalized.startsWith('ejecuta ') ||
        normalized.startsWith('programa ') ||
        normalized.startsWith('crea una regla') ||
        normalized.startsWith('abrir ') ||
        normalized.startsWith('toma una captura')) {
      return true;
    }
    return false;
  }

  /// Extrae todos los intentos lingüísticos presentes en el mensaje.
  Set<ConversationIntent> _extractIntents(String normalized, Set<String> tokens) {
    final intents = <ConversationIntent>{};

    // Saludo
    const greetingWords = {
      'hola',
      'holas',
      'buenas',
      'buenos',
      'hey',
      'oe',
      'saludos',
      'ola',
    };
    if (tokens.any(greetingWords.contains) ||
        normalized.contains('buen dia') ||
        normalized.contains('buenas tardes') ||
        normalized.contains('buenas noches')) {
      intents.add(ConversationIntent.greeting);
    }

    // Pregunta de bienestar / social check-in
    if (normalized.contains('como estas') ||
        normalized.contains('como te va') ||
        normalized.contains('como vas') ||
        normalized.contains('que tal') ||
        normalized.contains('como va todo') ||
        normalized.contains('como andas') ||
        normalized.contains('todo bien?') ||
        normalized.contains('todo bien ?')) {
      intents.add(ConversationIntent.askWellbeing);
    }

    // Respuesta de bienestar del usuario ("bien", "todo bien", "aquí tranquilo")
    if (normalized.contains('todo bien') ||
        normalized.contains('muy bien') ||
        normalized.contains('super bien') ||
        normalized.contains('excelente') ||
        normalized.contains('tranqui') ||
        normalized.contains('por aca bien') ||
        normalized.contains('aqui bien') ||
        (tokens.contains('bien') &&
            !normalized.contains('como') &&
            !normalized.contains('que tal'))) {
      intents.add(ConversationIntent.userWellbeing);
    }

    // Pregunta recíproca ("y tú", "y vos", "y usted", "qué tal tú")
    if (normalized.contains('y tu') ||
        normalized.contains('y vos') ||
        normalized.contains('y usted') ||
        normalized.contains('que tal tu') ||
        normalized.contains('y ti') ||
        normalized.contains('que tal vos')) {
      intents.add(ConversationIntent.reciprocalQuestion);
    }

    // Pregunta sobre actividad actual ("qué haces", "en qué andas", "qué cuentas")
    if (normalized.contains('que haces') ||
        normalized.contains('que haciendo') ||
        normalized.contains('que estas haciendo') ||
        normalized.contains('en que andas') ||
        normalized.contains('que cuentas') ||
        normalized.contains('que te cuentas') ||
        normalized.contains('que hay de nuevo') ||
        normalized.contains('que se cuenta')) {
      intents.add(ConversationIntent.askActivity);
    }

    // Pregunta sobre el día ("qué tal va tu día", "cómo va tu día")
    if (normalized.contains('tu dia') ||
        normalized.contains('el dia') ||
        normalized.contains('como va el dia') ||
        normalized.contains('como pinta el dia') ||
        normalized.contains('que tal va el dia')) {
      intents.add(ConversationIntent.askDay);
    }

    // Pregunta sobre entrenamiento / ejercicio / gym
    if (normalized.contains('entren') ||
        normalized.contains('gym') ||
        normalized.contains('gimnasio') ||
        normalized.contains('ejercicio')) {
      intents.add(ConversationIntent.askTraining);
    }

    // Pregunta de presencia ("estás ahí", "sigues ahí", "estás por ahí")
    if (normalized.contains('estas ahi') ||
        normalized.contains('estas por ahi') ||
        normalized.contains('sigues ahi') ||
        normalized.contains('estas hay') ||
        normalized == 'estas?' ||
        normalized == 'estas ?' ||
        normalized == 'estas') {
      intents.add(ConversationIntent.askPresence);
    }

    // Solicitud de ayuda / tarea / duda
    if (normalized.contains('tarea') ||
        normalized.contains('ayuda') ||
        normalized.contains('ayudas') ||
        normalized.contains('colaboras') ||
        normalized.contains('colaborar') ||
        normalized.contains('pregunta') ||
        normalized.contains('duda') ||
        normalized.contains('necesito')) {
      intents.add(ConversationIntent.askHelpOrQuestion);
    }

    // Agradecimiento
    if (tokens.contains('gracias') ||
        normalized.contains('muchas gracias') ||
        normalized.contains('mil gracias') ||
        normalized.contains('te agradezco')) {
      intents.add(ConversationIntent.thanks);
    }

    // Despedida
    if (tokens.contains('chao') ||
        tokens.contains('adios') ||
        normalized.contains('hasta luego') ||
        normalized.contains('nos vemos') ||
        normalized.contains('hablamos') ||
        tokens.contains('cuidate')) {
      intents.add(ConversationIntent.farewell);
    }

    // Risa
    if (tokens.any((t) =>
        t.startsWith('jaja') || t.startsWith('jeje') || t.startsWith('jajaj'))) {
      intents.add(ConversationIntent.laughter);
    }

    // Afirmación
    if (tokens.contains('dale') ||
        tokens.contains('listo') ||
        tokens.contains('ok') ||
        tokens.contains('perfecto')) {
      intents.add(ConversationIntent.affirmation);
    }

    // Si es saludo puro según el tokenizer pero no activó flag específico
    if (intents.isEmpty && isPureGreeting(normalized)) {
      intents.add(ConversationIntent.greeting);
    }

    return intents;
  }

  /// Compone una única respuesta fluida, auténtica y armónica.
  String? _composeUnifiedReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required Set<String> tokens,
    required String conversationId,
    required bool recentlyGreeted,
    required String? lastOutboundText,
  }) {
    // Caso 1: Pregunta recíproca ("bien y tú", "bien y vos", "todo bien y tú?")
    if (intents.contains(ConversationIntent.reciprocalQuestion) ||
        (intents.contains(ConversationIntent.userWellbeing) &&
            (normalized.contains('y tu') || normalized.contains('y vos')))) {
      const candidates = [
        '¡Bien también, gracias por preguntar! ¿Qué cuentas?',
        'Todo bien por acá también. ¿Qué tal va tu día?',
        '¡Bien, todo tranquilo por acá! ¿En qué andas hoy?',
        'Por acá todo en orden también. ¿Qué hay de nuevo?',
        '¡Excelente también, parce! ¿Qué estás haciendo?',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 2: Pregunta compuesta con entrenamiento ("hola emma cómo estás, qué tal va tu día, vas a ir hoy a entrenar?")
    if (intents.contains(ConversationIntent.askTraining)) {
      if (intents.contains(ConversationIntent.greeting) ||
          intents.contains(ConversationIntent.askDay) ||
          intents.contains(ConversationIntent.askWellbeing)) {
        if (!recentlyGreeted) {
          const candidates = [
            '¡Hola! Todo bien por acá y el día va tranquilo. Aún no sé seguro si entreno hoy, más tarde confirmo. ¿Y vos qué tal?',
            '¡Hola! Todo en orden por acá. Todavía no sé seguro lo del entreno de hoy, más tarde miro. ¿Vas a ir tú?',
            '¡Buenas! Por acá todo bien marchando tranquilo. Aún no sé si voy al gym hoy, luego te aviso. ¿Cómo vas tú?',
          ];
          return _selectCandidate(candidates, conversationId, lastOutboundText);
        } else {
          const candidates = [
            'Todo bien por acá y el día va tranquilo. Aún no sé seguro si entreno hoy, más tarde confirmo. ¿Y vos qué tal?',
            'Todo en orden por acá. Todavía no sé seguro lo del entreno de hoy, más tarde miro. ¿Vas a ir tú?',
            'Por acá todo bien marchando. Aún no sé seguro si entreno hoy, luego confirmo. ¿Y tú cómo vas?',
          ];
          return _selectCandidate(candidates, conversationId, lastOutboundText);
        }
      } else {
        // Pregunta de entrenamiento sola ("vas a entrenar hoy?", "entrenas hoy?")
        const candidates = [
          'Aún no sé seguro si voy a entrenar hoy, más tarde confirmo. ¿Y tú vas?',
          'Por ahora no estoy seguro del entreno de hoy, luego te aviso. ¿Vas a ir tú?',
          'Aún no sé si entreno hoy, más tarde miro. ¿Tú qué planes tienes?',
          'Aún no lo sé seguro, más tarde confirmo. ¿Y vos qué tal?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 3: Pregunta sobre el día ("qué tal va tu día", "cómo va tu día")
    if (intents.contains(ConversationIntent.askDay)) {
      if (intents.contains(ConversationIntent.greeting) && !recentlyGreeted) {
        const candidates = [
          '¡Hola! El día va marchando bien y tranquilo por acá. ¿Y el tuyo qué tal?',
          '¡Hola! Todo bien por acá, el día va bastante bien. ¿Cómo va el tuyo?',
          '¡Buenas! Por acá el día va muy bien, gracias por preguntar. ¿Y el tuyo cómo pinta?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          'El día va bien y tranquilo por acá, gracias. ¿Y el tuyo qué tal?',
          'Todo bien por acá, el día va marchando bien. ¿Cómo va el tuyo?',
          'Va bastante bien por acá, gracias por preguntar. ¿Y el tuyo cómo pinta?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 4: Pregunta sobre actividad ("qué haces", "en qué andas")
    if (intents.contains(ConversationIntent.askActivity)) {
      if (intents.contains(ConversationIntent.greeting) && !recentlyGreeted) {
        const candidates = [
          '¡Hola! Por acá tranquilo por ahora, aún no sé qué haré más tarde. ¿Y tú qué haces?',
          '¡Hola! Todo bien por acá, aún no estoy seguro de qué haré hoy. ¿Y vos en qué andas?',
          '¡Buenas! Por acá relajado en lo mío, aún no sé qué salga. ¿Qué cuentas de bueno?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          'Por acá tranquilo por ahora, aún no sé qué haré más tarde. ¿Y tú qué haces?',
          'Todo bien por acá, no estoy seguro de qué haré más tarde. ¿Y vos en qué andas?',
          'Por acá tranquilo en lo mío, aún no sé qué salga hoy. ¿Qué estás haciendo tú?',
          'Aquí todo en orden por ahora, aún no sé qué haré más rato. ¿Qué cuentas de bueno?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 5: Pregunta de presencia ("estás ahí?", "sigues ahí?")
    if (intents.contains(ConversationIntent.askPresence)) {
      const candidates = [
        '¡Sí, por acá estoy! Dime qué pasó.',
        'Sí, aquí estoy. Cuéntame qué tienes en mente.',
        'Por acá ando, claro. Dime qué necesitas, parce.',
        '¡Sí, aquí ando! Cuéntame.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 6: Solicitud de ayuda / tarea ("parce lo necesito para una tarea", "una pregunta")
    if (intents.contains(ConversationIntent.askHelpOrQuestion)) {
      const candidates = [
        '¡De una, parce! Cuéntame de qué se trata la tarea.',
        'Claro, de una. Dime qué necesitas y miramos.',
        '¡Hágale! Cuéntame qué tienes en mente y te colaboro.',
        'Claro que sí, dime cuál es la duda.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 7: Bienestar / Saludo + Bienestar ("cómo estás", "hola cómo estás", "qué tal")
    if (intents.contains(ConversationIntent.askWellbeing)) {
      if (recentlyGreeted) {
        const candidates = [
          '¡Bien, todo en orden por acá! ¿Y tú cómo vas?',
          'Todo bien por acá, tranquilo. ¿Qué tal tu día?',
          'Bien, todo marchando bien. ¿Qué cuentas de nuevo?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          '¡Hola! Bien, todo tranquilo por acá. ¿Y tú qué tal?',
          '¡Todo bien por acá, gracias a Dios! ¿Cómo vas tú?',
          '¡Por acá todo bien! ¿Qué tal va tu día?',
          '¡Todo en orden por acá! ¿Y vos cómo estás?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 8: Saludo simple ("hola", "hola emma", "buenas", "oe")
    if (intents.contains(ConversationIntent.greeting)) {
      if (recentlyGreeted) {
        const candidates = [
          '¡Hola de nuevo! ¿Qué cuentas?',
          '¿Qué más, parce? ¿En qué andas?',
          'Por acá sigo. ¿Qué tal todo?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          '¡Hola! ¿Cómo estás? ¿Qué tal todo?',
          '¡Hola! ¿Qué más, todo bien?',
          '¡Hola! ¿Cómo te va?',
          '¡Buenas! ¿Todo bien por allá?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 9: Agradecimiento ("gracias", "muchas gracias")
    if (intents.contains(ConversationIntent.thanks)) {
      const candidates = [
        '¡Con mucho gusto! Aquí a la orden.',
        '¡De nada, parce! Cualquier cosa me dices.',
        '¡Con todo gusto! Todo bien.',
        '¡De nada! Por acá a la orden.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 10: Despedida ("chao", "nos vemos")
    if (intents.contains(ConversationIntent.farewell)) {
      const candidates = [
        '¡Listo, nos vemos! Que te vaya bien.',
        '¡Hablamos pues, cuídate!',
        '¡De una, que estés muy bien!',
        '¡Dale, nos estamos hablando!',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 11: Risa casual ("jajaja")
    if (intents.contains(ConversationIntent.laughter)) {
      const candidates = [
        '¡Jajaja todo bien!',
        'Jajaja qué tal eso.',
        '¡Jajaja total!',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 12: Afirmación ("dale", "listo", "ok")
    if (intents.contains(ConversationIntent.affirmation)) {
      const candidates = [
        '¡Listo, de una!',
        '¡Dale, perfecto!',
        '¡Hágale pues!',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    return null;
  }

  /// Selecciona de manera determinista y temporal un candidato que no repita el último mensaje.
  String _selectCandidate(
    List<String> pool,
    String conversationId,
    String? lastOutboundText,
  ) {
    if (pool.isEmpty) return 'Todo bien por acá.';

    final minuteBucket = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final seed = (conversationId.hashCode ^ minuteBucket).abs();

    final available =
        pool.where((c) => c.trim() != lastOutboundText?.trim()).toList();
    final listToUse = available.isNotEmpty ? available : pool;

    return listToUse[seed % listToUse.length];
  }
}
