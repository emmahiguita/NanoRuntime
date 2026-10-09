part of 'conversation_agent_message_classifier.dart';

/// Clasifica la intención semántica de estado vivo del mensaje.
LiveStateIntent classifyLiveStateIntent(String messageText) {
  if (WeatherRequest.isSourceQuestion(messageText)) return LiveStateIntent.none;
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty) return LiveStateIntent.none;

  // 1. Preguntas de contexto conversacional / aclaración / seguimiento ("Dime qué sucede", "¿Qué pasó?"):
  // No piden la ubicación ni la actividad física del dueño.
  final isConversational =
      normalized.contains('que sucede') ||
      normalized.contains('que pasa') ||
      normalized.contains('que paso') ||
      normalized.contains('que ocurre') ||
      normalized.contains('como asi') ||
      normalized.contains('cuentame') ||
      normalized.contains('que quieres decir') ||
      normalized.contains('por que dices') ||
      normalized.contains('dime que');
  if (isConversational) return LiveStateIntent.conversationalContext;

  // 2. Bienestar cotidiano no es consulta de telemetría/estado vivo
  final isWellbeing =
      normalized.contains('como vas') ||
      normalized.contains('que tal') ||
      normalized.contains('como estas') ||
      normalized.contains('todo bien');
  if (isWellbeing &&
      !normalized.contains('vas a') &&
      !tokens.contains('donde')) {
    return LiveStateIntent.none;
  }

  // 3. Disponibilidad actual
  final isAvailability =
      normalized.contains('estas ocupado') ||
      normalized.contains('estas ocupada') ||
      normalized.contains('tienes tiempo') ||
      normalized.contains('estas libre') ||
      normalized.contains('puedes hablar') ||
      normalized.contains('te puedo llamar') ||
      normalized.contains('puedo llamar');
  if (isAvailability) return LiveStateIntent.currentAvailability;

  // 4. Ubicación actual
  final isLocation =
      (tokens.any((t) => t == 'donde' || t == 'ahi') &&
          (tokens.contains('vas') || tokens.any(presenceVerbs.contains))) ||
      normalized.contains('estas en casa') ||
      normalized.contains('estas en la casa');
  if (isLocation) return LiveStateIntent.currentLocation;

  // 5. Actividad o planes presentes
  if (tokens.contains('quieres') && tokens.contains('salir')) {
    return LiveStateIntent.currentActivity;
  }

  const activityVerbs = {
    'haces',
    'haciendo',
    'haras',
    'hacer',
    'iras',
    'planeas',
    'saldras',
    'entrenas',
  };
  final hasActivity = tokens.any(activityVerbs.contains);
  if (tokens.contains('que') && hasActivity) {
    return LiveStateIntent.currentActivity;
  }
  if (tokens.contains('hoy') && hasActivity) {
    return LiveStateIntent.currentActivity;
  }
  if (normalized.contains('vas a') ||
      normalized.contains('iras a') ||
      tokens.contains('planeas') ||
      (tokens.contains('vas') && tokens.contains('ir'))) {
    return LiveStateIntent.currentActivity;
  }

  const contextSensitive = [
    'como va tu dia',
    'que tal tu dia',
    'ya comiste',
    'almorzaste',
    'cenaste',
    'desayunaste',
    'tienes hambre',
    'como esta tu familia',
    'como estan todos',
    'vas a dormir',
    'sigues despierto',
    'que musica',
    'estas escuchando',
    'que opinas',
    'como lo ves',
  ];
  if (contextSensitive.any(normalized.contains)) {
    return LiveStateIntent.currentCondition;
  }

  return LiveStateIntent.none;
}

/// Detecta preguntas que requieren estado actual o percepción real del dueño.
bool isLiveStateQuestion(String messageText) {
  final intent = classifyLiveStateIntent(messageText);
  return intent == LiveStateIntent.currentActivity ||
      intent == LiveStateIntent.currentLocation ||
      intent == LiveStateIntent.currentAvailability ||
      intent == LiveStateIntent.currentCondition;
}
