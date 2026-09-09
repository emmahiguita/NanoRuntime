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

import '../../../../core/services/device_metrics.dart'
    show DeviceMetrics, DeviceMetricsData;
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
  askDeviceBattery,
  thanks,
  farewell,
  laughter,
  affirmation,
  negation,
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
  final Future<DeviceMetricsData> Function()? metricsSource;

  const PragmaticFastPath({
    this.memoryFor,
    this.contextEntryFor,
    this.ownerName,
    this.metricsSource,
  });

  static DeviceMetricsData? _cachedMetrics;
  static DateTime? _lastMetricsFetch;
  static const _metricsTtl = Duration(seconds: 10);

  Future<DeviceMetricsData?> _getMetrics() async {
    final now = DateTime.now();
    if (_cachedMetrics != null &&
        _lastMetricsFetch != null &&
        now.difference(_lastMetricsFetch!) < _metricsTtl) {
      return _cachedMetrics;
    }
    try {
      final m = await (metricsSource?.call() ?? DeviceMetrics.fetch());
      _cachedMetrics = m;
      _lastMetricsFetch = now;
      return m;
    } catch (_) {
      return null;
    }
  }

  /// Resuelve el turno conversacional o devuelve null para escalar al LLM / catálogo.
  Future<FastPathCandidate?> resolve({
    required String text,
    required String conversationId,
  }) async {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    final normalized = normalizeText(raw);
    final tokens = tokenizeText(normalized);
    if (tokens.isEmpty) return null;

    // 1. Guardias de escape estricto: Comercio, Soporte, Corrección, Comandos
    if (_hasCommercialOrCommandSignal(normalized, tokens)) {
      return null;
    }

    // 2. Escape de contenido narrativo / sustantivo / estado personal:
    // Si el usuario está contando qué hace, cómo está, qué hizo (programando, gym, cansado, etc.)
    // Fast Path NO debe secuestrar el turno con una plantilla estática.
    // Escapa al LLM para componer con memoria contextual y multi-intent.
    if (hasSubstantiveNarrative(normalized, tokens)) {
      return null;
    }

    // 3. Extraer el conjunto de intenciones comunicativas
    final intents = _extractIntents(normalized, tokens);
    if (intents.isEmpty) return null;

    // 4. Consultar hechos de hardware bajo demanda (Nivel 2) SOLO si la intención lo pide
    DeviceMetricsData? metrics;
    if (intents.contains(ConversationIntent.askDeviceBattery)) {
      metrics = await _getMetrics();
    }

    // 4. Inspeccionar historial de conversación reciente para anti-repetición
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

    // 5. Componer la respuesta unificada y natural
    final reply = _composeUnifiedReply(
      intents: intents,
      normalized: normalized,
      tokens: tokens,
      conversationId: conversationId,
      recentlyGreeted: recentlyGreeted,
      lastOutboundText: lastOutboundText,
      metrics: metrics,
    );

    if (reply == null || reply.trim().isEmpty) return null;

    final actLabel = intents.map((i) => i.name).join('+');
    return FastPathCandidate(
      act: actLabel,
      reply: reply,
      understanding: ConversationUnderstanding(
        reply: reply,
        intent: actLabel,
        relation: intents.contains(ConversationIntent.reciprocalQuestion) ||
                intents.contains(ConversationIntent.userWellbeing) ||
                intents.contains(ConversationIntent.negation)
            ? 'responde'
            : 'nuevo',
        questions: const [],
        missingFacts: const [],
        requiresAction: false,
      ),
    );
  }

  /// Verifica si el mensaje contiene intenciones de catálogo, compra, reclamo o comando.
  bool _hasCommercialOrCommandSignal(String normalized, Set<String> tokens) {
    // Las consultas de hardware (batería/dispositivo) usan palabras como "cuánta", "tienes",
    // pero son hechos de dispositivo, no compras ni catálogo comercial.
    final isHardwareInquiry = normalized.contains('bateria') ||
        normalized.contains('cuanta carga') ||
        normalized.contains('nivel de carga');

    if (!isHardwareInquiry && tokens.any(commercialIntentTokens.contains)) {
      return true;
    }
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

    // Negación
    if (tokens.contains('no') ||
        normalized.contains('para nada') ||
        normalized.contains('no gracias') ||
        normalized.contains('por ahora no')) {
      intents.add(ConversationIntent.negation);
    }

    // Pregunta sobre batería / carga del celular (Nivel 2: Fast Path + Android)
    if (normalized.contains('bateria') ||
        normalized.contains('cuanta carga') ||
        normalized.contains('cuanta bateria') ||
        normalized.contains('nivel de carga') ||
        normalized.contains('porcentaje de bateria') ||
        (normalized.contains('carga') &&
            (normalized.contains('tiene') ||
                normalized.contains('tienes') ||
                normalized.contains('queda')))) {
      intents.add(ConversationIntent.askDeviceBattery);
    }

    // Si es saludo puro según el tokenizer pero no activó flag específico
    if (intents.isEmpty && isPureGreeting(normalized)) {
      intents.add(ConversationIntent.greeting);
    }

    return intents;
  }

  /// Detecta si el mensaje contiene contenido narrativo, estado personal,
  /// actividades cotidianas o cláusulas compuestas que requieren memoria y composición LLM,
  /// evitando que Fast Path secuestre el turno con una plantilla genérica.
  static bool hasSubstantiveNarrative(String normalized, Set<String> tokens) {
    // Palabras clave de actividades, estados físicos, tecnología, deporte, lugares
    const narrativeTokens = {
      // Desarrollo / estudio / trabajo
      'programando', 'programar', 'programa', 'codigo', 'app', 'aplicacion',
      'agente', 'agentes', 'desarrollando', 'desarrollo', 'trabajando', 'trabajo',
      'camellando', 'camello', 'estudiando', 'estudio', 'universidad', 'colegio',
      'proyecto', 'reunion',
      // Estado físico / salud / cansancio
      'cansado', 'cansada', 'cansao', 'cansaod', 'cansadote', 'agotado', 'muerto', 'sueno',
      'dolor', 'enfermo', 'enferma', 'recuperando', 'pereza',
      // Ejercicio / gym
      'gimnasio', 'gym', 'entrenando', 'entrene', 'entreno', 'pecho', 'espalda',
      'pierna', 'brazo', 'pesas', 'trotando', 'corriendo', 'bici', 'futbol',
      // Ubicación / actividades cotidianas
      'casa', 'cuarto', 'cama', 'calle', 'oficina', 'comiendo', 'almorzando',
      'cenando', 'cocinando', 'manejando', 'viajando', 'paseando',
      // Verbos de acción narrativa
      'terminando', 'empezando', 'sali', 'llegue', 'acabe',
    };

    if (tokens.any(narrativeTokens.contains)) return true;

    // Frases que indican estado o relato del usuario
    if (normalized.contains('en casa') ||
        normalized.contains('en el gym') ||
        normalized.contains('al gym') ||
        normalized.contains('al gimnasio') ||
        normalized.contains('del gym') ||
        normalized.contains('del trabajo') ||
        normalized.contains('estoy muerto') ||
        normalized.contains('algo cansado') ||
        normalized.contains('algo cansaod') ||
        normalized.contains('muy cansado') ||
        normalized.contains('bastante cansado') ||
        normalized.contains('mi dia va') ||
        normalized.contains('el mio va') ||
        normalized.contains('ando en') ||
        normalized.contains('ando haciendo') ||
        normalized.contains('estoy en')) {
      return true;
    }

    // Si el mensaje es una interacción cotidiana o check-in social (saludo, estado básico, pregunta de actividad),
    // NO es una narrativa sustantiva aunque use "estoy" o "ando".
    final nonSocial = normalized
        .replaceAll('estoy bien', '')
        .replaceAll('estoy muy bien', '')
        .replaceAll('estoy super bien', '')
        .replaceAll('ando bien', '')
        .replaceAll('estoy tranquilo', '')
        .replaceAll('ando tranquilo', '')
        .replaceAll('que haces', '')
        .replaceAll('que haciendo', '')
        .replaceAll('que cuentas', '')
        .replaceAll('como estas', '')
        .replaceAll('como te va', '')
        .replaceAll('como vas', '')
        .replaceAll('hola', '')
        .replaceAll('buenas', '')
        .replaceAll('oe', '')
        .replaceAll('emma', '')
        .replaceAll('parce', '')
        .replaceAll(RegExp(r'[·,;?!]'), ' ')
        .trim();

    final remainingTokens = tokenizeText(nonSocial);
    if (remainingTokens.length > 3 &&
        (remainingTokens.contains('estoy') ||
            remainingTokens.contains('ando') ||
            remainingTokens.contains('sali') ||
            remainingTokens.contains('fui') ||
            remainingTokens.contains('hice') ||
            remainingTokens.contains('hago') ||
            remainingTokens.contains('voy') ||
            remainingTokens.contains('tengo'))) {
      return true;
    }

    return false;
  }

  /// Compone una única respuesta fluida, auténtica y armónica.
  String? _composeUnifiedReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required Set<String> tokens,
    required String conversationId,
    required bool recentlyGreeted,
    required String? lastOutboundText,
    DeviceMetricsData? metrics,
  }) {
    // Caso 1: Pregunta recíproca pura de bienestar ("bien y tú", "bien y vos", "todo bien y tú?")
    // NO agrega preguntas automáticas (Regla de oro: responde sin interrogar al interlocutor).
    if (intents.contains(ConversationIntent.reciprocalQuestion) ||
        (intents.contains(ConversationIntent.userWellbeing) &&
            (normalized.contains('y tu') || normalized.contains('y vos')))) {
      const candidates = [
        'Bien también.',
        'Bien también, todo tranquilo.',
        'Todo bien por acá.',
        'Por acá todo bien también.',
        'Bien también por acá.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 1B: Bienestar del usuario + pregunta de actividad ("estoy bien y qué haces", "todo bien por acá y qué haces?", "bien por acá, en qué andas?")
    if (intents.contains(ConversationIntent.userWellbeing) &&
        intents.contains(ConversationIntent.askActivity)) {
      const candidates = [
        'Qué bueno. Aquí haciendo unas cosas.',
        'Qué bueno. Por acá en lo mío, hablando contigo.',
        'Qué bien. Por acá tranquilo haciendo unas cosas.',
        'Me alegra. Por acá en lo mío por ahora.',
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
            '¡Hola! Todo bien por acá y el día va tranquilo. Aún no sé seguro si entreno hoy.',
            '¡Hola! Todo en orden por acá. Todavía no sé seguro lo del entreno de hoy.',
            '¡Buenas! Por acá todo bien marchando tranquilo.',
          ];
          return _selectCandidate(candidates, conversationId, lastOutboundText);
        } else {
          const candidates = [
            'Todo bien por acá y el día va tranquilo.',
            'Todo en orden por acá.',
            'Por acá todo bien marchando.',
          ];
          return _selectCandidate(candidates, conversationId, lastOutboundText);
        }
      } else {
        // Pregunta de entrenamiento sola ("vas a entrenar hoy?", "entrenas hoy?")
        const candidates = [
          'Aún no sé seguro si voy a entrenar hoy, más tarde confirmo.',
          'Por ahora no estoy seguro del entreno de hoy.',
          'Aún no sé si entreno hoy, más tarde miro.',
          'Aún no lo sé seguro, más tarde confirmo.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 3: Pregunta sobre el día ("qué tal va tu día", "cómo va tu día")
    if (intents.contains(ConversationIntent.askDay)) {
      if (intents.contains(ConversationIntent.greeting) && !recentlyGreeted) {
        const candidates = [
          '¡Hola! El día va marchando bien y tranquilo por acá.',
          '¡Hola! Todo bien por acá, el día va bastante bien.',
          '¡Buenas! Por acá el día va muy bien.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          'El día va bien y tranquilo por acá.',
          'Todo bien por acá, el día va marchando bien.',
          'Va bastante bien por acá.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 4: Pregunta sobre actividad ("qué haces", "en qué andas", "hola emma cómo estás qué haces hoy")
    // Responde naturalmente como presencia sin interrogar automáticamente de vuelta.
    if (intents.contains(ConversationIntent.askActivity)) {
      final withWellbeing = intents.contains(ConversationIntent.askWellbeing);
      if (intents.contains(ConversationIntent.greeting) && !recentlyGreeted) {
        final candidates = withWellbeing
            ? [
                '¡Hola! Bien por acá, aquí haciendo unas cosas.',
                '¡Hola! Todo bien por acá, aquí en lo mío.',
                '¡Hola! Bien, por acá hablando contigo jaja.',
              ]
            : [
                '¡Hola! Aquí hablando contigo jaja.',
                '¡Hola! Por acá tranquilo por ahora.',
                '¡Buenas! Aquí en lo mío por ahora.',
              ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        final candidates = withWellbeing
            ? [
                'Bien por acá, aquí haciendo unas cosas.',
                'Todo bien por acá, aquí en lo mío.',
                'Bien por acá, hablando contigo jaja.',
              ]
            : [
                'Aquí hablando contigo jaja.',
                'Por acá tranquilo por ahora.',
                'Aquí en lo mío por ahora.',
                'Todo bien por acá, hablando contigo.',
              ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
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

    // Caso 6: Solicitud de ayuda / tarea ("parce lo necesito para una tarea", "parce necesito ayuda", "una pregunta")
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

    // Caso 7: Bienestar / Saludo + Bienestar ("cómo estás", "hola cómo estás", "qué tal")
    if (intents.contains(ConversationIntent.askWellbeing)) {
      if (recentlyGreeted) {
        const candidates = [
          'Bien, todo en orden por acá.',
          'Todo bien por acá, tranquilo.',
          'Bien, todo marchando bien.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          'Bien, todo tranquilo. ¿Y tú?',
          '¡Hola! Bien, todo tranquilo por acá.',
          '¡Todo bien por acá, gracias a Dios!',
          '¡Por acá todo bien!',
          '¡Todo en orden por acá!',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 8: Saludo simple ("hola", "hola emma", "buenas", "oe")
    if (intents.contains(ConversationIntent.greeting)) {
      if (recentlyGreeted) {
        const candidates = [
          '¡Hola! Aquí pendiente.',
          'Por acá sigo.',
          'Dime.',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      } else {
        const candidates = [
          '¡Hola! ¿Cómo vas?',
          'Hola, ¿todo bien?',
          '¡Buenas! ¿Cómo te va?',
        ];
        return _selectCandidate(candidates, conversationId, lastOutboundText);
      }
    }

    // Caso 9: Agradecimiento ("gracias", "muchas gracias")
    if (intents.contains(ConversationIntent.thanks)) {
      const candidates = [
        'De una, fresco.',
        'Con gusto.',
        'Por acá a la orden.',
        'De una.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 10: Despedida ("chao", "nos vemos")
    if (intents.contains(ConversationIntent.farewell)) {
      const candidates = [
        'Hablamos pues, cuídate.',
        'De una, nos vemos.',
        'Dale, que estés bien.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 11: Risa ("jajaja", "jeje", "jaja literal")
    if (intents.contains(ConversationIntent.laughter)) {
      const candidates = [
        '😂',
        'Literal jaja',
        'Jaja tal cual',
        'Jajaja sí',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 12: Afirmación ("dale", "listo", "ok", "exacto")
    if (intents.contains(ConversationIntent.affirmation) ||
        normalized == 'exacto' ||
        normalized == 'tal cual' ||
        normalized == 'literal') {
      const candidates = [
        'De una.',
        'Total.',
        'Exacto.',
        'Listo pues.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 13: Negación ("no", "no gracias", "para nada", "por ahora no")
    if (intents.contains(ConversationIntent.negation)) {
      const candidates = [
        '¡Listo, dale! Cualquier cosa me avisas.',
        'De una, fresco. Cualquier cosa me dices.',
        'Listo, de una.',
        'Dale, todo bien.',
      ];
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    // Caso 14: Hecho de hardware bajo demanda: Batería (Nivel 2: Fast Path + Android)
    if (intents.contains(ConversationIntent.askDeviceBattery)) {
      final pct = metrics?.batteryPct.round() ?? -1;
      final charging = metrics?.isCharging ?? false;
      if (pct >= 0) {
        final withGreeting =
            intents.contains(ConversationIntent.greeting) && !recentlyGreeted;
        if (charging) {
          return withGreeting
              ? '¡Hola! Tengo el $pct% y está cargando.'
              : 'Tengo el $pct% y está cargando.';
        } else {
          return withGreeting
              ? '¡Hola! Tengo el $pct% de batería por ahora.'
              : 'Tengo el $pct% de batería por ahora.';
        }
      } else {
        // Hardware no reportó datos válidos: null para no inventar
        return null;
      }
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
