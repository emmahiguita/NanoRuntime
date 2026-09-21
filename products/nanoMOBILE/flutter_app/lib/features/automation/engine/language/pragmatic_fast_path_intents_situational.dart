part of 'pragmatic_fast_path.dart';

/// Extracción de intenciones comunicativas situacionales cotidianas para PragmaticFastPath (< 150 LOC).
///
/// **QUÉ HACE:**
/// Identifica preguntas situacionales frecuentes (disponibilidad, comida, ubicación física/casa,
/// familia, descanso/sueño, música, clima, llamada telefónica, ausencia y opiniones).
///
/// **CÓMO FUNCIONA:**
/// Comprueba patrones idiomáticos y expresiones coloquiales sobre el texto normalizado.
///
/// **POR QUÉ:**
/// Separa las situaciones de vida cotidiana de las consultas objetivas (hora, fecha, batería),
/// garantizando que cada archivo del clasificador mida estrictamente menos de 200 líneas.
extension _PragmaticSituationalIntents on PragmaticFastPath {
  void _extractSituationalIntents(
    Set<ConversationIntent> intents,
    String normalized,
  ) {
    if (normalized.contains('estas ocupado') ||
        normalized.contains('andas ocupado') ||
        normalized.contains('estas ocupada') ||
        normalized.contains('andas ocupada') ||
        normalized.contains('tienes tiempo') ||
        normalized.contains('puedes hablar') ||
        normalized.contains('estas libre') ||
        normalized.contains('andas libre') ||
        normalized.contains('tienes un momento') ||
        normalized.contains('tienes un minuto') ||
        normalized.contains('tienes un ratico') ||
        normalized.contains('puedes responder')) {
      intents.add(ConversationIntent.askAvailability);
    }

    if (normalized.contains('almorzaste') ||
        normalized.contains('ya comiste') ||
        normalized.contains('cenaste') ||
        normalized.contains('desayunaste') ||
        normalized.contains('vas a comer') ||
        normalized.contains('que almorzaste') ||
        normalized.contains('que comiste') ||
        normalized.contains('que cenaste') ||
        normalized.contains('tienes hambre')) {
      intents.add(ConversationIntent.askFood);
    }

    if (normalized.contains('estas en la casa') ||
        normalized.contains('andas en la casa') ||
        normalized.contains('estas en casa') ||
        normalized.contains('andas en casa') ||
        normalized.contains('estas en tu casa') ||
        normalized.contains('en la casa?') ||
        normalized.contains('en la casa ?') ||
        normalized.contains('en casa?')) {
      intents.add(ConversationIntent.askPhysicalLocation);
    }

    if (normalized.contains('tu familia') ||
        normalized.contains('la familia') ||
        normalized.contains('en tu casa') ||
        normalized.contains('los tuyos') ||
        normalized.contains('todos en tu casa') ||
        normalized.contains('como van todos') ||
        normalized.contains('como estan todos') ||
        normalized.contains('como esta la gente')) {
      intents.add(ConversationIntent.askFamily);
    }

    if (normalized.contains('vas a dormir') ||
        normalized.contains('te vas a dormir') ||
        normalized.contains('sigues despierto') ||
        normalized.contains('andas despierto') ||
        normalized.contains('trasnochando') ||
        normalized.contains('no puedes dormir') ||
        normalized.contains('despierto a esta hora') ||
        normalized.contains('te vas a acostar')) {
      intents.add(ConversationIntent.askSleep);
    }

    if (normalized.contains('estas escuchando') ||
        normalized.contains('que musica') ||
        normalized.contains('escuchando musica') ||
        normalized.contains('que tema') ||
        normalized.contains('que cancion') ||
        normalized.contains('que beat') ||
        normalized.contains('oyendo musica')) {
      intents.add(ConversationIntent.askMusic);
    }

    if (normalized.contains('lloviendo') ||
        normalized.contains('esta lloviendo') ||
        normalized.contains('mucho calor') ||
        normalized.contains('hace calor') ||
        normalized.contains('hace frio') ||
        normalized.contains('como esta el clima') ||
        normalized.contains('que tal el clima')) {
      intents.add(ConversationIntent.askWeatherSocial);
    }

    if (normalized.contains('puedo llamar') ||
        normalized.contains('te puedo llamar') ||
        normalized.contains('te puedo marcar') ||
        normalized.contains('hacemos llamada') ||
        normalized.contains('hablar por llamada') ||
        normalized.contains('tiempo para una llamada') ||
        normalized.contains('te marco') ||
        normalized.contains('te llamo')) {
      intents.add(ConversationIntent.askCall);
    }

    if (normalized.contains('te perdiste') ||
        normalized.contains('que te hiciste') ||
        normalized.contains('tan perdido') ||
        normalized.contains('por que tan perdido') ||
        normalized.contains('andas perdido') ||
        normalized.contains('donde te metiste')) {
      intents.add(ConversationIntent.askLostOrMissing);
    }

    if (normalized.contains('como lo ves') ||
        normalized.contains('que opinas') ||
        normalized.contains('te gusta') ||
        normalized.contains('que tal te parece') ||
        normalized.contains('como te parece') ||
        normalized.contains('que te parece') ||
        normalized.contains('esta bacano') ||
        normalized.contains('esta chimba')) {
      intents.add(ConversationIntent.askOpinionSocial);
    }
  }
}
