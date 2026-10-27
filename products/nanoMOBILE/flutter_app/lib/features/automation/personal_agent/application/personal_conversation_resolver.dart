import '../../engine/conversation/dialogue_state_tracker.dart';
import '../../engine/conversation/knowledge_need_gate.dart';
import '../../engine/conversation/personal_style_formatter.dart';
import '../../engine/conversation/persona_style_resolver.dart';
import '../../engine/conversation/turn_context_router.dart';
import '../../engine/conversation/turn_knowledge_router.dart';
import '../../engine/language/dialogue_act_classifier.dart';
import '../../engine/language/hybrid_intent_classifier.dart';
import '../../engine/language/pragmatic_fast_path.dart';

import '../../engine/messaging/conversation_memory.dart';
import '../../engine/notifications/notification_object.dart';
import '../domain/conversation_agent_message_classifier.dart';

import '../domain/personal_intent.dart';

import 'personal_intent_router.dart';
import 'personal_memory_fact_resolver.dart';
import 'personal_turn_reply.dart';
import 'personal_turn_selector.dart';
import 'personalization_scope_resolver.dart';

export 'personal_turn_reply.dart';

/// Orquestador de resolución de turnos personales de Nano.
///
/// - **QUÉ HACE:** Prioriza que el modelo local LiteRT-LM redacte respuestas
///   naturales y contextuales con múltiples opciones usando `<CONTEXTO DEL TURNO>`,
///   y provee respaldo seguro si el motor local no está disponible.
/// - **CÓMO FUNCIONA:** En [resolveEarlyTurn] delega todas las preguntas de
///   hora, fecha, agenda, estado vivo y charla cotidiana al modelo local
///   (retornando `null`), evitando frases robóticas o enlatadas.
/// La calidad depende de la inferencia real; este resolver no fabrica frases.
class PersonalConversationResolver {
  final TurnKnowledgeRouter? knowledgeRouter;
  final PersonalStyleFormatter styleFormatter;
  final PersonalMemoryFactResolver memoryFactResolver;

  const PersonalConversationResolver({
    @Deprecated('Los saludos se redactan con el modelo')
    PragmaticFastPath? fastPath,
    @Deprecated('El estilo pertenece al contexto del modelo')
    PersonaStyleResolver? styleResolver,
    @Deprecated('La comprensión se realiza en el pipeline contextual')
    HybridIntentClassifier? intentClassifier,
    @Deprecated('Las opciones deben proceder de la generación real')
    PersonalTurnSelector? turnSelector,
    @Deprecated('El writer resuelve el ámbito del contexto')
    PersonalizationScopeResolver? scopeResolver,
    this.knowledgeRouter,
    this.styleFormatter = const RuntimePersonalStyleFormatter(),
    this.memoryFactResolver = const PersonalMemoryFactResolver(),
  });

  /// Decide si un turno puede resolverse por un dato puntual de memoria o si
  /// debe pasar directamente al modelo local LiteRT-LM.
  ///
  /// - **QUÉ HACE:** Retorna `null` para saludos, preguntas de hora/fecha,
  ///   cronograma del día, estado vivo y párrafos narrativos para que LiteRT-LM
  ///   los responda con naturalidad y opciones de respuesta.
  /// - **CÓMO FUNCIONA:** Filtra intenciones temporales/agenda y preguntas de
  ///   estado vivo antes de consultar [memoryFactResolver].
  /// - **POR QUÉ:** Elimina las respuestas robóticas precodificadas que antes
  ///   cortocircuitaban al modelo.
  Future<PersonalTurnReply?> resolveEarlyTurn({
    required NotificationObject notification,
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required String conversationId,
    ConversationDialogueState? dialogueState,
  }) async {
    final personalIntent = PersonalIntentRouter.route(analysis.targetText);
    if (personalIntent == PersonalIntent.currentTime ||
        personalIntent == PersonalIntent.currentDate ||
        personalIntent == PersonalIntent.nanoDailyPlan ||
        personalIntent == PersonalIntent.userDailyPlan ||
        personalIntent == PersonalIntent.userPendingTasks ||
        isLiveStateQuestion(analysis.targetText) ||
        analysis.isClarificationRequest ||
        analysis.targetComplexity.isComplex ||
        analysis.targetComplexity.isNarrative) {
      return null;
    }
    return memoryFactResolver.resolve(
      userText: analysis.targetText,
      conversationId: conversationId,
      memory: memory,
    );
  }

  /// Respaldo cuando el motor local LiteRT-LM aún no está cargado o falla.
  ///
  /// Consulta fuentes configuradas cuando aplica; nunca convierte ausencia
  /// de agenda en disponibilidad ni fabrica variantes si falla el modelo.
  Future<PersonalTurnReply?> resolveFallbackTurn({
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required String conversationId,
  }) async {
    if (isLiveStateQuestion(analysis.targetText)) return null;
    final router = knowledgeRouter;
    if (router == null) return null;
    final act = const DialogueActClassifier()
        .classify(analysis.targetText)
        .primaryAct;
    final gate = const KnowledgeNeedGate().evaluate(
      text: analysis.targetText,
      act: act,
    );
    if (gate.needsExternalKnowledge &&
        router.needsExternalKnowledge(analysis.targetText)) {
      final result = await router.fetchKnowledge(analysis.targetText);
      if (result.hasFacts && result.rawKnowledge.trim().isNotEmpty) {
        final styled = styleFormatter.formatKnowledge(
          rawFacts: result.rawKnowledge,
          query: analysis.targetText,
        );
        return PersonalTurnReply(
          text: styled.text,
          understanding: styled.understanding,
          suggestions: styled.suggestions,
          isFast: false,
        );
      }
    }
    // La nube generativa ya pertenece al writer y conserva contexto/consentimiento.
    // No repetir el mensaje personal como consulta a otro buscador o proveedor.
    return null;
  }
}
