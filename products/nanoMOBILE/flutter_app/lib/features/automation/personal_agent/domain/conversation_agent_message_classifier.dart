// conversation_agent_message_classifier.dart
//
// QUÉ HACE:
// Clasificador determinista de mensajes entrantes (saludos extendidos, correcciones,
// risas coloquiales, reacciones sociales y preguntas de estado presente).
//
// CÓMO FUNCIONA:
// - Analiza patrones textuales normalizados y complejidad sintáctica (`turnComplexityClassifier`).
// - Distingue un saludo genuino de un mensaje de negocio o una pregunta de estado en vivo.
// - Detecta risa libre con typos (`_looseLaughter`) y preguntas sobre estado en tiempo real.
//
// POR QUÉ:
// Mantiene el código ordenado bajo SRP, garantizando que el router principal permanezca en < 200 líneas.

library;

import '../../engine/business/fact_selector.dart'
    show normalizeText, tokenizeText;
import '../../engine/language/turn_complexity_classifier.dart'
    show turnComplexityClassifier;
import '../../engine/messaging/conv_turn_state.dart'
    show greetingTokens, isPureGreeting;
import 'conversation_agent_tokens.dart';

final RegExp _looseLaughter = RegExp(r'(ja){2,}|(je){2,}|(ji){2,}|(jo){2,}');

/// Evalúa si el mensaje contiene frases de corrección meta-conversacional.
bool isCorrectionMessage(String messageText) =>
    correctionPhrases.any(normalizeText(messageText).contains);

/// Identifica saludos sociales puros o con cortesía/vocativo/bienestar.
bool isGreetingLikeMessage(String messageText) {
  if (isLiveStateQuestion(messageText)) return false;
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty) return false;
  if (tokens.any(commercialIntentTokens.contains)) return false;
  if (supportPhrases.any(normalized.contains)) return false;
  if (correctionPhrases.any(normalized.contains)) return false;
  if (normalized.contains('vas a') || normalized.contains('iras a')) return false;

  const compoundTokens = {
    'haces', 'haciendo', 'haras', 'hacer', 'salir', 'saldras', 'iras',
    'tienes', 'tenes', 'todavia', 'aun', 'telefono', 'celular', 'hablaste',
    'dijiste', 'viste', 'fuiste', 'pudiste', 'sabes', 'puedes', 'quieres',
    'necesitas', 'vendes', 'compras', 'llevas', 'partido', 'futbol',
    'programando', 'programa', 'programar', 'codigo', 'app', 'aplicacion',
    'agente', 'agentes', 'trabajando', 'trabajo', 'camellando', 'cansado',
    'cansada', 'cansao', 'cansaod', 'agotado', 'muerto', 'gimnasio', 'gym',
    'entrenando', 'entreno', 'pecho', 'espalda', 'pierna', 'casa', 'calle',
    'estoy', 'ando', 'sali', 'fui', 'tarea', 'ayuda', 'duda', 'pregunta',
  };
  if (tokens.any(compoundTokens.contains)) return false;
  if (isPureGreeting(messageText)) return true;

  const explicitGreetingWords = {
    'hola', 'holas', 'buenas', 'buenos', 'hey', 'oe', 'saludos', 'ola',
  };
  final hasGreeting =
      tokens.take(3).any(explicitGreetingWords.contains) ||
      (tokens.first != 'que' && greetingTokens.contains(tokens.first)) ||
      (tokens.first == 'que' && tokens.length >= 2 && tokens.contains('tal')) ||
      normalized.contains('como vas') ||
      normalized.contains('que tal') ||
      normalized.contains('todo bien');
  if (!hasGreeting) return false;

  final complexity = turnComplexityClassifier.classify(messageText);
  if (complexity.isNarrative || complexity.isComplex || complexity.isContextual) {
    return false;
  }
  return tokens.length <= 8;
}

/// Identifica reacciones o continuaciones sociales ("gracias", "dale", "de una").
bool isSocialReactionMessage(String messageText) =>
    tokenizeText(normalizeText(messageText)).any(socialReactionTokens.contains);

/// Detecta preguntas que requieren estado actual o percepción real del dueño.
bool isLiveStateQuestion(String messageText) {
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty) return false;

  // Bienestar cotidiano no es consulta de telemetría/estado vivo
  final isWellbeing = normalized.contains('como vas') ||
      normalized.contains('que tal') ||
      normalized.contains('como estas') ||
      normalized.contains('todo bien');
  if (isWellbeing && !normalized.contains('vas a') && !tokens.contains('donde')) {
    return false;
  }

  const activityVerbs = {
    'haces', 'haciendo', 'haras', 'hacer', 'iras', 'planeas', 'saldras', 'entrenas',
  };
  final hasActivity = tokens.any(activityVerbs.contains);
  if (tokens.contains('que') && hasActivity) return true;
  if (tokens.contains('hoy') && hasActivity) return true;
  if (tokens.any((t) => t == 'donde' || t == 'ahi') &&
      (tokens.contains('vas') || tokens.any(presenceVerbs.contains))) {
    return true;
  }
  if (normalized.contains('vas a') ||
      normalized.contains('iras a') ||
      tokens.contains('planeas') ||
      (tokens.contains('vas') && tokens.contains('ir'))) {
    return true;
  }

  const contextSensitive = [
    'como va tu dia', 'que tal tu dia', 'estas ocupado', 'estas ocupada',
    'tienes tiempo', 'estas libre', 'puedes hablar', 'ya comiste', 'almorzaste',
    'cenaste', 'desayunaste', 'tienes hambre', 'estas en casa', 'estas en la casa',
    'como esta tu familia', 'como estan todos', 'vas a dormir', 'sigues despierto',
    'que musica', 'estas escuchando', 'como esta el clima', 'esta lloviendo',
    'hace frio', 'hace calor', 'te puedo llamar', 'puedo llamar', 'que opinas',
    'como lo ves',
  ];
  return contextSensitive.any(normalized.contains);
}

/// Evalúa risa informal desordenada ("jajaja", "jajsjaja").
bool isLooseLaughterMessage(String messageText) =>
    _looseLaughter.hasMatch(normalizeText(messageText));
