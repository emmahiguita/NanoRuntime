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

part 'conversation_agent_greeting_classifier.dart';
part 'conversation_agent_live_state_classifier.dart';

final RegExp _looseLaughter = RegExp(r'(ja){2,}|(je){2,}|(ji){2,}|(jo){2,}');

/// Evalúa si el mensaje contiene frases de corrección meta-conversacional.
bool isCorrectionMessage(String messageText) =>
    correctionPhrases.any(normalizeText(messageText).contains);

/// Identifica reacciones o continuaciones sociales ("gracias", "dale", "de una").
bool isSocialReactionMessage(String messageText) =>
    tokenizeText(normalizeText(messageText)).any(socialReactionTokens.contains);

/// Evalúa risa informal desordenada ("jajaja", "jajsjaja").
bool isLooseLaughterMessage(String messageText) =>
    _looseLaughter.hasMatch(normalizeText(messageText));
