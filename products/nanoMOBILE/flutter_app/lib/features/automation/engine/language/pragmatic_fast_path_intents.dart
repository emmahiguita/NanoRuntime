part of 'pragmatic_fast_path.dart';

/// Orquestador de extracción de intenciones y filtros de escape para PragmaticFastPath (< 60 LOC).
///
/// **QUÉ HACE:**
/// Discrimina si el mensaje contiene intenciones comerciales o de comando que deban
/// escapar del fast-path, y coordina la extracción de intenciones básicas, contextuales y situacionales.
///
/// **CÓMO FUNCIONA:**
/// - Si detecta intención comercial, soporte, corrección o comando de terminal, aborta el fast path.
/// - Invoca `_extractBasicIntents`, `_extractContextualIntents` y `_extractSituationalIntents`.
/// - Aplica fallback a `ConversationIntent.greeting` si el tokenizer lo reconoce como saludo puro.
///
/// **POR QUÉ:**
/// Actúa como fachada y punto de entrada cohesivo (Clean Architecture) manteniendo
/// los submódulos especializados en menos de 200 líneas cada uno.
extension _PragmaticIntentExtraction on PragmaticFastPath {
  bool _hasCommercialOrCommandSignal(String normalized, Set<String> tokens) {
    final isHardwareInquiry = normalized.contains('bateria') ||
        normalized.contains('cuanta carga') ||
        normalized.contains('nivel de carga');

    if (!isHardwareInquiry && tokens.any(commercialIntentTokens.contains)) return true;
    if (supportPhrases.any(normalized.contains)) return true;
    if (correctionPhrases.any(normalized.contains)) return true;

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
    _extractBasicIntents(intents, normalized, tokens);
    _extractContextualIntents(intents, normalized, tokens);
    _extractSituationalIntents(intents, normalized);

    if (intents.isEmpty && isPureGreeting(normalized)) {
      intents.add(ConversationIntent.greeting);
    }
    return intents;
  }
}
