/// PragmaticFastPath (A07) — speech acts triviales SIN LLM.
///
/// ANDROID FIRST / DETERMINISTIC SECOND / SMALL LLM LAST: un saludo o un
/// agradecimiento puros no necesitan 1.5B tokens de inferencia. Este escalón
/// reutiliza las señales existentes de ConversationAgentRole (jamás keyword
/// hell nuevo) y responde con frase natural rotada por conversación
/// (determinista — mismo hash, misma frase; jamás aleatorio).
///
/// Límites estrictos (invariantes del brief):
/// - SOLO alta confianza: saludo puro o agradecimiento puro, cortos, sin
///   señales de contenido (comercial/soporte/corrección) y sin pregunta
///   embebida. Cualquier duda → null → LLM (escalation, A09).
/// - Afirmación/negación ("sí", "no", "dale") NUNCA pasan por aquí: requieren
///   referente pendiente (YES/NO MUST HAVE A REFERENT) → siempre LLM.
/// - El reply NO es autoridad: el ConversationDecisionEngine corre IGUAL
///   sobre el entendimiento determinista (eco, call-center, wrong-turn...).
/// - Jamás copia errores del input (INPUT ERROR != OWNER STYLE): frases
///   limpias fijas.
library;

import '../../personal_agent/domain/conversation_agent_role.dart'
    show
        correctionPhrases,
        commercialIntentTokens,
        isLiveStateQuestion,
        supportPhrases;
import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import '../notifications/conversation_understanding.dart';
import '../messaging/conv_turn_state.dart' show isPureGreeting;

final class FastPathCandidate {
  /// 'saludo' | 'agradecimiento' (traza física).
  final String act;
  final String reply;
  final ConversationUnderstanding understanding;

  const FastPathCandidate({
    required this.act,
    required this.reply,
    required this.understanding,
  });
}

final class PragmaticFastPath {
  const PragmaticFastPath();

  /// Frases naturales por acto. Rotación determinista por conversación.
  static const _greetingReplies = ['Hola, ¿cómo estás?', 'Hola, ¿todo bien?'];
  static const _thanksReplies = ['¡De nada!', 'Con gusto.'];

  /// Devuelve el candidato de fast path o null (= escalar a LLM).
  FastPathCandidate? resolve({
    required String text,
    required String conversationId,
  }) {
    final act = _classify(text);
    if (act == null) return null;
    final pool = act == 'saludo' ? _greetingReplies : _thanksReplies;
    final index = conversationId.hashCode.abs() % pool.length;
    final reply = pool[index];
    return FastPathCandidate(
      act: act,
      reply: reply,
      understanding: ConversationUnderstanding(intent: act, reply: reply),
    );
  }

  String? _classify(String text) {
    final normalized = normalizeText(text);
    final tokens = tokenizeText(normalized);
    if (tokens.isEmpty || tokens.length > 4 || isLiveStateQuestion(text)) {
      return null;
    }
    if (isPureGreeting(text)) return 'saludo';
    // Pregunta embebida ("¿gracias, cuánto vale?") → LLM: hay algo que
    // responder además del agradecimiento.
    if (normalized.contains('?')) return null;
    if (tokens.any((t) => t == 'no')) return null;
    // Señales de contenido: el acto trivial con carga comercial/soporte/
    // corrección o pregunta de estado NO es trivial.
    if (tokens.any(commercialIntentTokens.contains)) return null;
    if (supportPhrases.any(normalized.contains)) return null;
    if (correctionPhrases.any(normalized.contains)) return null;
    if (isLiveStateQuestion(text)) return null;
    if (tokens.contains('gracias')) return 'agradecimiento';
    return null;
  }
}
