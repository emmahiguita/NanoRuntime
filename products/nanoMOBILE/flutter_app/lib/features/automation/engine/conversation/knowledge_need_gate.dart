// knowledge_need_gate.dart
//
// QUÉ HACE:
// Compuerta de necesidad de conocimiento (KnowledgeNeedGate) para gobernar qué ramas
// de recuperación y generación están autorizadas para el turno conversacional.
//
// CÓMO FUNCIONA:
// Evalúa el texto, el acto conversacional (DialogueAct) y las intenciones del turno para
// emitir un KnowledgeNeedDecision inmutable que prohíbe terminantemente búsquedas
// externas o inferencias pesadas en turnos sociales, de reacción o de estado en vivo.
//
// POR QUÉ:
// Previene el fallo crítico donde un "me alegra" o un saludo termina consultando Wikipedia
// o la Web buscando ciudades o noticias no relacionadas.
// Cumple SOLID (SRP, OCP) y Clean Architecture (< 180 líneas).

library;

import '../business/fact_selector.dart' show normalizeText;
import '../language/dialogue_act.dart';
import '../../personal_agent/domain/conversation_agent_message_classifier.dart'
    show isLiveStateQuestion;

/// Decisión formal sobre los requerimientos de conocimiento del turno.
final class KnowledgeNeedDecision {
  final bool needsExternalKnowledge;
  final bool needsPersonalMemory;
  final bool needsLiveState;
  final bool needsConversationHistory;
  final bool canAnswerLocally;
  final bool allowsWebSearch;
  final bool allowsLongFormGeneration;
  final String rationale;

  const KnowledgeNeedDecision({
    required this.needsExternalKnowledge,
    required this.needsPersonalMemory,
    required this.needsLiveState,
    required this.needsConversationHistory,
    required this.canAnswerLocally,
    required this.allowsWebSearch,
    required this.allowsLongFormGeneration,
    required this.rationale,
  });

  /// Decisión canónica para actos sociales/reactivos: CERO búsqueda externa.
  static const socialLocal = KnowledgeNeedDecision(
    needsExternalKnowledge: false,
    needsPersonalMemory: false,
    needsLiveState: false,
    needsConversationHistory: true,
    canAnswerLocally: true,
    allowsWebSearch: false,
    allowsLongFormGeneration: false,
    rationale: 'Turno social o de reacción: resuelto puramente con cortesía local',
  );

  /// Decisión canónica para estado o actividad viva del dueño.
  static const ownerLiveFact = KnowledgeNeedDecision(
    needsExternalKnowledge: false,
    needsPersonalMemory: true,
    needsLiveState: true,
    needsConversationHistory: true,
    canAnswerLocally: true,
    allowsWebSearch: false,
    allowsLongFormGeneration: false,
    rationale: 'Pregunta de estado vivo o planes del dueño: gobernada por veracidad local',
  );
}

final class KnowledgeNeedGate {
  const KnowledgeNeedGate();

  static const _externalKeywords = {
    'que paso con', 'que paso hoy', 'viste que paso', 'supiste que paso',
    'sabes algo de', 'noticias de', 'precio del dolar', 'cuanto esta el dolar',
    'precio de bitcoin', 'como quedo el partido', 'quien gano', 'a que hora juega',
    'clima en', 'va a llover', 'cuando sale', 'cuando se estrena', 'android 16',
    'android 17', 'chatgpt', 'deepseek', 'gemini', 'openai',
  };

  /// Evalúa rigurosamente los requerimientos de conocimiento para el [text] y [act].
  KnowledgeNeedDecision evaluate({
    required String text,
    required DialogueAct act,
    String? detectedIntent,
  }) {
    // 1. Invariante P0: Actos puramente sociales o reactivos jamás requieren búsqueda externa.
    if (act.isPurelySocial || act == DialogueAct.repairRequest || act == DialogueAct.continuation) {
      return KnowledgeNeedDecision.socialLocal;
    }

    // 2. Invariante P0: Preguntas de estado o actividad del dueño no son búsquedas web.
    if (isLiveStateQuestion(text)) {
      return KnowledgeNeedDecision.ownerLiveFact;
    }

    final norm = normalizeText(text);

    // 3. Chequeo de intención explícita de conocimiento externo
    final hasExternalSignal = _externalKeywords.any(norm.contains) ||
        norm.contains('noticia') ||
        norm.contains('resultado') ||
        norm.contains('quien es') ||
        norm.contains('que es');

    if (act == DialogueAct.question && hasExternalSignal) {
      return const KnowledgeNeedDecision(
        needsExternalKnowledge: true,
        needsPersonalMemory: false,
        needsLiveState: false,
        needsConversationHistory: false,
        canAnswerLocally: false,
        allowsWebSearch: true,
        allowsLongFormGeneration: true,
        rationale: 'Pregunta factual sobre entidad, evento o actualidad externa',
      );
    }

    // 4. Default: conversación natural sin necesidad de crawling web
    return KnowledgeNeedDecision(
      needsExternalKnowledge: false,
      needsPersonalMemory: true,
      needsLiveState: false,
      needsConversationHistory: true,
      canAnswerLocally: true,
      allowsWebSearch: false,
      allowsLongFormGeneration: act == DialogueAct.statement,
      rationale: 'Turno conversacional estándar: atendido con memoria local y estilo',
    );
  }
}
