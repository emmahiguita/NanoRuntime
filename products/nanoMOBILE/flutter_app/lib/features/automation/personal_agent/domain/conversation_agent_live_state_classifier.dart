// QUÉ: identifica consultas que requieren hechos actuales del dueño.
// CÓMO: conserva reglas previas y reconoce la invitación observada a salir.
// POR QUÉ: el estilo conversacional no demuestra voluntad ni disponibilidad.
part of 'conversation_agent_message_classifier.dart';

/// Detecta preguntas que requieren estado actual o percepción real del dueño.
bool isLiveStateQuestion(String messageText) {
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty) return false;

  // Una invitación directa requiere la voluntad actual del dueño, no su estilo.
  // Activa el contrato estructurado y las barreras ya existentes de hechos vivos.
  if (tokens.contains('quieres') && tokens.contains('salir')) return true;

  // Bienestar cotidiano no es consulta de telemetría/estado vivo
  final isWellbeing =
      normalized.contains('como vas') ||
      normalized.contains('que tal') ||
      normalized.contains('como estas') ||
      normalized.contains('todo bien');
  if (isWellbeing &&
      !normalized.contains('vas a') &&
      !tokens.contains('donde')) {
    return false;
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
    'como va tu dia',
    'que tal tu dia',
    'estas ocupado',
    'estas ocupada',
    'tienes tiempo',
    'estas libre',
    'puedes hablar',
    'ya comiste',
    'almorzaste',
    'cenaste',
    'desayunaste',
    'tienes hambre',
    'estas en casa',
    'estas en la casa',
    'como esta tu familia',
    'como estan todos',
    'vas a dormir',
    'sigues despierto',
    'que musica',
    'estas escuchando',
    'como esta el clima',
    'esta lloviendo',
    'hace frio',
    'hace calor',
    'te puedo llamar',
    'puedo llamar',
    'que opinas',
    'como lo ves',
  ];
  return contextSensitive.any(normalized.contains);
}
