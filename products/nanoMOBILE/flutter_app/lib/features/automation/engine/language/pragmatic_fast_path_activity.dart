part of 'pragmatic_fast_path.dart';

/// Respuestas para preguntas sobre actividad y planes del dueño.
///
/// **QUÉ HACE:**
/// Resuelve de forma determinista intenciones skActivity, diferenciando
/// planes futuros, desplazamientos/salidas y actividades cotidianas presentes.
///
/// **CÓMO FUNCIONA:**
/// Examina los tokens y términos normalizados para mapear a los bancos de
/// candidatos de pragmatic_fast_path_activity_banks.dart usando _selectCandidate.
///
/// **POR QUÉ:**
/// Separa la lógica de decisión de los catálogos textuales, manteniendo el archivo
/// pequeño (< 100 LOC) y garantizando respuestas naturales con más de 10 opciones.
extension _PragmaticFastPathActivity on PragmaticFastPath {
  ({String reply, List<String> suggestions})? _composeActivityReply({
    required Set<ConversationIntent> intents,
    required String normalized,
    required String conversationId,
    required bool recentlyGreeted,
    required String? lastOutboundText,
  }) {
    if (!intents.contains(ConversationIntent.askActivity)) return null;

    if (normalized.contains('salir') ||
        normalized.contains('en la noche') ||
        normalized.contains('sale hoy') ||
        normalized.contains('vas a ir') ||
        normalized.contains('vas ir')) {
      return _selectCandidate(activityGoingCandidates, conversationId, lastOutboundText);
    }

    if (normalized.contains('que haras') ||
        normalized.contains('haras hoy') ||
        normalized.contains('que haran') ||
        normalized.contains('que vas a hacer') ||
        normalized.contains('que vas hacer') ||
        normalized.contains('vas hacer') ||
        normalized.contains('vas a hacer') ||
        normalized.contains('que planes') ||
        normalized.contains('tienes pensado')) {
      return _selectCandidate(activityPlansCandidates, conversationId, lastOutboundText);
    }

    final withWellbeing = intents.contains(ConversationIntent.askWellbeing);
    if (intents.contains(ConversationIntent.greeting) && !recentlyGreeted) {
      final candidates = withWellbeing
          ? activityGreetingWithWellbeingCandidates
          : activityGreetingCandidates;
      return _selectCandidate(candidates, conversationId, lastOutboundText);
    }

    final candidates = withWellbeing
        ? activityWithWellbeingCandidates
        : activityGeneralCandidates;
    return _selectCandidate(candidates, conversationId, lastOutboundText);
  }
}
