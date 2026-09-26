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
  socialReassurance,
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
  userCorrection;

  /// Clasificación de enrutamiento explícita de cada intención (Ciclo 13).
  FastPathRoutingClass get routingClass {
    switch (this) {
      case ConversationIntent.greeting:
      case ConversationIntent.askWellbeing:
      case ConversationIntent.userWellbeing:
      case ConversationIntent.reciprocalQuestion:
      case ConversationIntent.thanks:
      case ConversationIntent.farewell:
      case ConversationIntent.laughter:
      case ConversationIntent.affirmation:
      case ConversationIntent.negation:
      case ConversationIntent.wellbeingClarification:
      case ConversationIntent.socialReassurance:
      case ConversationIntent.userCorrection:
      case ConversationIntent.askPresence:
      case ConversationIntent.askDeviceBattery:
      case ConversationIntent.askTime:
      case ConversationIntent.askDate:
      case ConversationIntent.askLocation:
      case ConversationIntent.askActivity:
      case ConversationIntent.askFood:
      case ConversationIntent.askPhysicalLocation:
      case ConversationIntent.askSleep:
      case ConversationIntent.askAvailability:
      case ConversationIntent.askDay:
      case ConversationIntent.askTraining:
      case ConversationIntent.askRap:
      case ConversationIntent.askFamily:
      case ConversationIntent.askMusic:
      case ConversationIntent.askWeatherSocial:
      case ConversationIntent.askCall:
      case ConversationIntent.askLostOrMissing:
      case ConversationIntent.askOpinionSocial:
      case ConversationIntent.invitation:
        return FastPathRoutingClass.safeDeterministic;
      case ConversationIntent.planReminder:
      case ConversationIntent.askHelpOrQuestion:
        return FastPathRoutingClass.llmRequired;
    }
  }
}

/// Categorías de enrutamiento de FastPath (Ciclo 13: FastPath = optimización).
enum FastPathRoutingClass {
  safeDeterministic,
  contextRequired,
  liveStateRequired,
  llmRequired,
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
