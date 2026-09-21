import '../notifications/conversation_understanding.dart';

/// Intento comunicativo elemental detectado en el texto conversacional.
///
/// **QUÉ HACE:**
/// Define las categorías semánticas y pragmáticas reconocidas por el fast-path.
///
/// **CÓMO FUNCIONA:**
/// Es un enum puro evaluado por matchers léxicos deterministas en <5ms.
///
/// **POR QUÉ:**
/// Tipifica fuertemente las intenciones del usuario sin depender de strings mágicos
/// ni incurrir en latencia o consumo de batería del LLM.
enum ConversationIntent {
  greeting,
  askWellbeing,
  userWellbeing,
  reciprocalQuestion,
  askActivity,
  askDay,
  askTraining,
  askRap,
  invitation,
  askPresence,
  askHelpOrQuestion,
  askDeviceBattery,
  askTime,
  askDate,
  askLocation,
  planReminder,
  thanks,
  farewell,
  laughter,
  affirmation,
  negation,
  wellbeingClarification,
  askAvailability,
  askFood,
  askPhysicalLocation,
  askFamily,
  askSleep,
  askMusic,
  askWeatherSocial,
  askCall,
  askLostOrMissing,
  askOpinionSocial,
}

/// Candidato de respuesta generado por el motor pragmático sin LLM.
///
/// **QUÉ HACE:**
/// Encapsula la respuesta sugerida, su etiqueta de acto comunicativo y su understanding.
///
/// **CÓMO FUNCIONA:**
/// Transporta el texto inmutable y las opciones de sugerencia rápida para la UI o despacho directo.
///
/// **POR QUÉ:**
/// Provee una estructura unificada entre el motor determinista y el clasificador de diálogo.
final class FastPathCandidate {
  final String act;
  final String reply;
  final ConversationUnderstanding understanding;
  final List<String> suggestions;

  const FastPathCandidate({
    required this.act,
    required this.reply,
    required this.understanding,
    this.suggestions = const [],
  });
}
