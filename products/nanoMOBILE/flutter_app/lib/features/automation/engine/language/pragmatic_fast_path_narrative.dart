part of 'pragmatic_fast_path.dart';

/// Detección de contenido narrativo, estado personal y actividades cotidianas.
/// Evita que FastPath secuestre el turno cuando se requiere memoria o composición LLM.
/// Cumple SOLID y límite de < 300 líneas.
extension _PragmaticFastPathNarrative on PragmaticFastPath {
  static bool hasSubstantiveNarrative(String normalized, Set<String> tokens) {
    // Preguntas dirigidas al dueño sobre actividades, planes o día ("qué vas a hacer", "vas a salir", "qué haces", "vamos a rapear")
    // NO son relato del usuario: deben responderse inmediatamente vía Fast Path.
    if (normalized.contains('que vas') ||
        normalized.contains('vas a') ||
        normalized.contains('que haces') ||
        normalized.contains('que haciendo') ||
        normalized.contains('que estas haciendo') ||
        normalized.contains('que haras') ||
        normalized.contains('haras hoy') ||
        normalized.contains('vas hacer') ||
        normalized.contains('vamos a salir') ||
        normalized.contains('vas a salir') ||
        normalized.contains('vamos a rapear') ||
        normalized.contains('vamos a') ||
        normalized.contains('vamos ?') ||
        normalized.contains('vamos?') ||
        normalized == 'vamos' ||
        normalized.contains('rapear') ||
        normalized.contains('tirar rimas') ||
        normalized.contains('que planes') ||
        normalized.contains('en que andas') ||
        normalized.contains('estas ocupado') ||
        normalized.contains('almorzaste') ||
        normalized.contains('ya comiste') ||
        normalized.contains('estas en la casa') ||
        normalized.contains('vas a dormir') ||
        normalized.contains('te perdiste') ||
        normalized.contains('como lo ves') ||
        normalized.contains('puedo llamar') ||
        normalized.contains('que cuentas')) {
      return false;
    }

    // Despedidas, negaciones sociales breves, reaseguros de bienestar y cierres de conversación
    if (normalized.contains('descans') ||
        normalized.contains('hasta manana') ||
        normalized.contains('feliz noche') ||
        normalized.contains('buenas noches') ||
        normalized.contains('feliz tarde') ||
        normalized.contains('que estes bien') ||
        normalized.contains('que este bien') ||
        normalized.contains('hablamos') ||
        normalized.contains('nos vemos') ||
        normalized.contains('chao') ||
        normalized.contains('adios') ||
        normalized == 'no' ||
        normalized == 'no creo' ||
        normalized == 'creo que no' ||
        normalized == 'hoy no creo' ||
        normalized == 'por ahora no' ||
        normalized == 'no gracias' ||
        normalized.contains('te dije que bien') ||
        normalized.contains('ya te dije que bien') ||
        normalized.contains('te dije que estoy bien') ||
        normalized.contains('ya te dije que estoy bien') ||
        normalized.contains('ya te dije que todo bien') ||
        normalized.contains('te acabo de decir') ||
        tokens.contains('cuidate')) {
      return false;
    }

    // Delegación al clasificador determinista unificado de complejidad de turno
    final classification = turnComplexityClassifier.classify(normalized);
    if (classification.isNarrative ||
        classification.isComplex ||
        classification.isContextual) {
      return true;
    }

    // Palabras clave de actividades, estados físicos, tecnología, deporte, lugares
    const narrativeTokens = {
      // Desarrollo / estudio / trabajo
      'programando', 'programar', 'programa', 'codigo', 'app', 'aplicacion',
      'agente', 'agentes', 'desarrollando', 'desarrollo', 'trabajando',
      'trabajo', 'camellando', 'camello', 'estudiando', 'estudio',
      'universidad', 'colegio', 'proyecto', 'reunion',
      // Estado físico / salud / cansancio
      'cansado', 'cansada', 'cansao', 'cansaod', 'cansadote', 'agotado',
      'muerto', 'sueno', 'dolor', 'enfermo', 'enferma', 'recuperando', 'pereza',
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

    // Si el mensaje es una interacción cotidiana o check-in social
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
}
