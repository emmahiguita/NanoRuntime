// personal_conversation_resolver.dart
// QUÉ HACE: Orquesta turnos conversacionales del Agente Personal desde "Hola" hasta párrafos extensos.
// CÓMO FUNCIONA: 1. Memoria/correferencias -> 2. Clasificador híbrido + Estilo -> 3. Conocimiento -> 4. Opciones.
// POR QUÉ: Cumple SOLID (SRP, OCP, DIP), Clean Architecture y límite estricto < 200 líneas.

library;

export 'personal_turn_reply.dart';

import '../../engine/conversation/dialogue_state_tracker.dart' show ConversationDialogueState;
import '../../engine/conversation/personal_style_formatter.dart';
import '../../engine/conversation/persona_style_resolver.dart';
import '../../engine/conversation/turn_context_router.dart';
import '../../engine/conversation/turn_knowledge_router.dart';
import '../../engine/language/hybrid_intent_classifier.dart';
import '../../engine/language/pragmatic_fast_path.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/notifications/conversation_understanding.dart';
import '../../engine/notifications/notification_object.dart';
import '../../engine/conversation/knowledge_need_gate.dart';
import '../../engine/language/dialogue_act_classifier.dart';
import '../domain/conversation_agent_message_classifier.dart' show isLiveStateQuestion;
import 'personal_memory_fact_resolver.dart';
import 'personal_turn_reply.dart';
import 'personal_turn_selector.dart';
import 'personalization_scope_resolver.dart';

class PersonalConversationResolver {
  final PersonaStyleResolver? styleResolver;
  final TurnKnowledgeRouter? knowledgeRouter;
  final PragmaticFastPath fastPath;
  final PersonalStyleFormatter styleFormatter;
  final PersonalMemoryFactResolver memoryFactResolver;
  final HybridIntentClassifier intentClassifier;
  final PersonalTurnSelector turnSelector;
  final PersonalizationScopeResolver scopeResolver;

  const PersonalConversationResolver({
    this.fastPath = const PragmaticFastPath(),
    this.styleResolver, this.knowledgeRouter,
    this.styleFormatter = const RuntimePersonalStyleFormatter(),
    this.memoryFactResolver = const PersonalMemoryFactResolver(),
    this.intentClassifier = const HybridIntentClassifier(),
    this.turnSelector = const PersonalTurnSelector(),
    this.scopeResolver = const CanonicalPersonalizationScopeResolver(),
  });

  /// QUÉ HACE: Resuelve turnos tempranos deterministas con prioridad en memoria, estilo y búsqueda externa.
  /// CÓMO FUNCIONA: Consulta memoria factual y luego resuelve estilo jerárquico según el scope.
  /// POR QUÉ: Responde al instante con contexto real y 3 opciones naturales sin bloquear el hilo UI.
  Future<PersonalTurnReply?> resolveEarlyTurn({
    required NotificationObject notification,
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required String conversationId,
    ConversationDialogueState? dialogueState,
  }) async {
    if (isLiveStateQuestion(analysis.targetText)) {
      final n = analysis.targetText.toLowerCase();
      if (!n.contains('haces') && !n.contains('haciendo') && !n.contains('como vas')) return null;
    }

    if (analysis.isClarificationRequest &&
        dialogueState?.lastAgentStatement != null &&
        dialogueState!.lastAgentStatement!.trim().isNotEmpty) {
      final prev = dialogueState.lastAgentStatement!.trim();
      final reply = 'Jajaja, te preguntaba: $prev';
      final opts = ['Te preguntaba: $prev', 'Que $prev', 'Decía que $prev'];
      return PersonalTurnReply(
        text: reply,
        understanding: ConversationUnderstanding(reply: reply, intent: 'clarification_repair', options: opts),
        suggestions: opts,
        isFast: true,
      );
    }

    final mem = await memoryFactResolver.resolve(
      userText: analysis.targetText, conversationId: conversationId, memory: memory);
    if (mem != null) return mem;

    final hybrid = intentClassifier.classify(analysis.targetText);
    final hasPendingQ = dialogueState?.hasPendingQuestion ?? false;
    final allowLiteral = !hybrid.blocksLiteralStyleReuse &&
        !hasPendingQ &&
        !analysis.isClarificationRequest &&
        !analysis.hasContextualContinuity &&
        !analysis.targetComplexity.isNarrative &&
        !analysis.targetComplexity.isContextual &&
        !analysis.targetComplexity.isComplex;

    final scopes = await scopeResolver.resolveScopes(
      conversationId: conversationId, senderId: notification.sender);

    final styleMatch = (allowLiteral && styleResolver != null)
        ? await _resolveStyle(analysis.targetText, notification.text, conversationId, scopes, 0.60)
        : null;
    // QUÉ HACE: permite respuestas locales sólo para actos sociales sin hechos personales.
    // CÓMO: exige turno social breve y limita las intenciones a saludo/cortesía/despedida/risa.
    // POR QUÉ: un saludo no debe esperar al LLM ni afirmar actividad del dueño sin evidencia.
    final candidate = analysis.targetComplexity.isSocialMinimal
        ? await fastPath.resolve(
            text: analysis.targetText,
            conversationId: conversationId,
            memoryOverride: memory,
          )
        : null;
    final fastMatch = candidate != null && _isSafeSocialFastPath(candidate.act)
        ? candidate
        : null;
    final best = turnSelector.selectBestCandidate(
      userText: analysis.targetText,
      conversationId: conversationId,
      memory: memory,
      styleMatch: styleMatch,
      fastMatch: fastMatch,
    );
    if (best != null) return best;

    final act = const DialogueActClassifier().classify(analysis.targetText).primaryAct;
    final gate = const KnowledgeNeedGate().evaluate(text: analysis.targetText, act: act);
    if (gate.needsExternalKnowledge && knowledgeRouter != null && knowledgeRouter!.needsExternalKnowledge(analysis.targetText)) {
      return _resolveExternalKnowledge(analysis.targetText, isFast: true);
    }
    return null;
  }

  // QUÉ HACE: admite únicamente respuestas fáticas que no afirman datos del dueño.
  // CÓMO: comprueba todas las intenciones detectadas, no sólo la primera.
  // POR QUÉ: preguntas ambiguas y estados personales deben pasar por memoria o modelo.
  bool _isSafeSocialFastPath(String act) {
    const allowed = {'greeting', 'thanks', 'farewell', 'laughter'};
    final intents = act.split('+');
    return intents.isNotEmpty && intents.every(allowed.contains);
  }

  /// QUÉ HACE: Busca una respuesta aprendida o hechos externos si falla el borrador del modelo.
  /// CÓMO FUNCIONA: Solo devuelve estilo guardado o conocimiento recuperado y validable.
  /// POR QUÉ: Sin evidencia suficiente, no genera ni envía una frase prefabricada.
  Future<PersonalTurnReply?> resolveFallbackTurn({
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required String conversationId,
  }) async {
    final scopes = await scopeResolver.resolveScopes(conversationId: conversationId, senderId: '');
    final related = styleResolver != null
        ? await styleResolver!.resolve(
            text: analysis.targetText,
            conversationId: conversationId,
            scopeKey: scopes.first,
            candidateScopes: scopes,
            minConfidence: 0.50,
          )
        : null;
    final candidate = turnSelector.selectBestCandidate(
      userText: analysis.targetText,
      conversationId: conversationId,
      memory: memory,
      styleMatch: related,
      fastMatch: null,
    );
    if (candidate != null) return candidate;

    final act = const DialogueActClassifier().classify(analysis.targetText).primaryAct;
    final gate = const KnowledgeNeedGate().evaluate(text: analysis.targetText, act: act);
    if (gate.needsExternalKnowledge && knowledgeRouter != null && knowledgeRouter!.needsExternalKnowledge(analysis.targetText)) {
      final ext = await _resolveExternalKnowledge(analysis.targetText, isFast: false);
      if (ext != null) return ext;
    }

    // QUÉ HACE: cierra sin candidato si la recuperación no encontró respaldo.
    // CÓMO: null impide que el dispatcher convierta una frase genérica en envío automático.
    // POR QUÉ: sin modelo, memoria ni hechos verificados, cualquier respuesta sería inventada.
    return null;
  }

  Future<PersonaStyleMatch?> _resolveStyle(
      String target, String raw, String convId, List<String> scopes, double minConf) async {
    final primary = await styleResolver!.resolve(
      text: target, conversationId: convId, scopeKey: scopes.first, candidateScopes: scopes, minConfidence: minConf);
    return primary ?? (target == raw ? null : styleResolver!.resolve(
      text: raw, conversationId: convId, scopeKey: scopes.first, candidateScopes: scopes, minConfidence: minConf));
  }

  Future<PersonalTurnReply?> _resolveExternalKnowledge(String query, {required bool isFast}) async {
    final ext = await knowledgeRouter!.fetchKnowledge(query);
    if (!ext.hasFacts || ext.rawKnowledge.trim().isEmpty) return null;
    final styled = styleFormatter.formatKnowledge(rawFacts: ext.rawKnowledge, query: query);
    return PersonalTurnReply(
      text: styled.text, understanding: styled.understanding, suggestions: styled.suggestions, isFast: isFast);
  }
}
