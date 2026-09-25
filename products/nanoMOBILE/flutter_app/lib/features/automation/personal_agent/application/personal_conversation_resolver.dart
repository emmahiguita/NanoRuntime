// personal_conversation_resolver.dart
// QUÉ HACE: Orquesta turnos conversacionales del Agente Personal desde un "Hola" hasta párrafos extensos.
// CÓMO FUNCIONA: 1. Memoria y correferencias -> 2. Clasificador híbrido + Estilo/FastPath -> 3. Conocimiento -> 4. Opciones dinámicas.
// POR QUÉ: Cumple SOLID (SRP, OCP, DIP), Clean Architecture y el límite estricto de < 200 líneas sin frases robóticas.

import '../../engine/conversation/personal_style_formatter.dart';
import '../../engine/conversation/persona_style_resolver.dart';
import '../../engine/conversation/turn_context_router.dart';
import '../../engine/conversation/turn_knowledge_router.dart';
import '../../engine/language/hybrid_intent_classifier.dart';
import '../../engine/language/pragmatic_fast_path.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/notifications/conversation_understanding.dart';
import '../../engine/notifications/notification_object.dart';
import '../domain/conversation_agent_message_classifier.dart'
    show isLiveStateQuestion;
import 'personal_memory_fact_helpers.dart' show PersonalMemoryFactHelpers;
import 'personal_memory_fact_resolver.dart';
import 'personal_turn_selector.dart';

/// QUÉ HACE: Encapsula la respuesta del Agente Personal junto con sus opciones seleccionables.
/// CÓMO FUNCIONA: Almacena el texto principal, la estructura `ConversationUnderstanding` y la lista `suggestions`.
/// POR QUÉ: Garantiza que la UI reciba tanto la respuesta sugerida como múltiples alternativas humanas.
final class PersonalTurnReply {
  final String text;
  final ConversationUnderstanding understanding;
  final List<String> suggestions;
  final bool isFast;

  const PersonalTurnReply({
    required this.text,
    required this.understanding,
    this.suggestions = const [],
    this.isFast = true,
  });
}

/// QUÉ HACE: Orquestador con responsabilidad única sobre la resolución conversacional del Agente Personal.
/// CÓMO FUNCIONA: Coordina memoria personal/conversacional, clasificación de cláusulas y generación de opciones.
/// POR QUÉ: Evita respuestas estáticas o fuera de contexto ante saludos breves o párrafos largos.
class PersonalConversationResolver {
  final PragmaticFastPath? fastPath;
  final PersonaStyleResolver? styleResolver;
  final TurnKnowledgeRouter? knowledgeRouter;
  final PersonalStyleFormatter styleFormatter;
  final PersonalMemoryFactResolver _memoryFactResolver;
  final HybridIntentClassifier _intentClassifier;
  final PersonalTurnSelector _turnSelector;

  const PersonalConversationResolver({
    this.fastPath,
    this.styleResolver,
    this.knowledgeRouter,
    this.styleFormatter = const RuntimePersonalStyleFormatter(),
    PersonalMemoryFactResolver memoryFactResolver =
        const PersonalMemoryFactResolver(),
    HybridIntentClassifier intentClassifier = const HybridIntentClassifier(),
    PersonalTurnSelector turnSelector = const PersonalTurnSelector(),
  }) : _memoryFactResolver = memoryFactResolver,
       _intentClassifier = intentClassifier,
       _turnSelector = turnSelector;

  /// QUÉ HACE: Resuelve turnos tempranos deterministas con prioridad en memoria, estilo y búsqueda externa.
  /// CÓMO FUNCIONA: Consulta `_memoryFactResolver` (que maneja desde "Hola" hasta párrafos multi-cláusula) y luego FastPath.
  /// POR QUÉ: Responde al instante con contexto real y 3 opciones naturales sin bloquear el hilo UI.
  Future<PersonalTurnReply?> resolveEarlyTurn({
    required NotificationObject notification,
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required String conversationId,
  }) async {
    if (isLiveStateQuestion(analysis.targetText)) return null;

    final memoryResolved = await _memoryFactResolver.resolve(
      userText: analysis.targetText,
      conversationId: conversationId,
      memory: memory,
    );
    if (memoryResolved != null) return memoryResolved;

    final hybrid = _intentClassifier.classify(analysis.targetText);
    final allowLiteral = !hybrid.blocksLiteralStyleReuse &&
        !analysis.hasContextualContinuity &&
        !analysis.targetComplexity.isNarrative &&
        !analysis.targetComplexity.isContextual &&
        !analysis.targetComplexity.isComplex;

    final styleMatch = (allowLiteral && styleResolver != null)
        ? await _resolveStyle(analysis.targetText, notification.text, conversationId, 0.60)
        : null;
    final fastMatch = (allowLiteral && analysis.isFastPathEligible && fastPath != null)
        ? await _resolveFast(analysis.targetText, notification.text, conversationId, memory)
        : null;

    final bestEarly = _turnSelector.selectBestCandidate(
      userText: analysis.targetText,
      conversationId: conversationId,
      memory: memory,
      styleMatch: styleMatch,
      fastMatch: fastMatch,
    );
    if (bestEarly != null) return bestEarly;

    if (knowledgeRouter != null &&
        knowledgeRouter!.needsExternalKnowledge(analysis.targetText)) {
      return _resolveExternalKnowledge(analysis.targetText, isFast: true);
    }
    return null;
  }

  /// QUÉ HACE: Resuelve el fallback conversacional cuando el motor generativo local no está activo.
  /// CÓMO FUNCIONA: Intenta coincidencia flexible, luego conocimiento externo y finalmente opciones dinámicas contextuales.
  /// POR QUÉ: Garantiza que el usuario siempre tenga 3 opciones naturales adaptadas al mensaje recibido.
  Future<PersonalTurnReply?> resolveFallbackTurn({
    required TurnRoutingAnalysis analysis,
    required ConversationMemory? memory,
    required String conversationId,
  }) async {
    if (isLiveStateQuestion(analysis.targetText)) return null;

    final related = styleResolver != null
        ? await styleResolver!.resolve(
            text: analysis.targetText,
            conversationId: conversationId,
            minConfidence: 0.50,
          )
        : null;
    final fast = fastPath != null
        ? await fastPath!.resolve(
            text: analysis.targetText,
            conversationId: conversationId,
            memoryOverride: memory,
          )
        : null;

    final candidate = _turnSelector.selectBestCandidate(
      userText: analysis.targetText,
      conversationId: conversationId,
      memory: memory,
      styleMatch: related,
      fastMatch: fast,
    );
    if (candidate != null) return candidate;

    if (knowledgeRouter != null) {
      final ext = await _resolveExternalKnowledge(analysis.targetText, isFast: false);
      if (ext != null) return ext;
    }

    final dynamicOpts = PersonalMemoryFactHelpers.buildDynamicOptions(
      userText: analysis.targetText,
      topics: PersonalMemoryFactHelpers.extractConversationTopics(
        memory,
        currentText: analysis.targetText,
      ),
    );
    return PersonalTurnReply(
      text: dynamicOpts.first,
      understanding: ConversationUnderstanding(
        intent: 'personal_dialogue_fallback',
        reply: dynamicOpts.first,
        options: dynamicOpts,
      ),
      suggestions: dynamicOpts,
      isFast: true,
    );
  }

  Future<PersonaStyleMatch?> _resolveStyle(
      String target, String raw, String convId, double minConf) async =>
      await styleResolver!.resolve(text: target, conversationId: convId, minConfidence: minConf) ??
      (target != raw
          ? await styleResolver!.resolve(text: raw, conversationId: convId, minConfidence: minConf)
          : null);

  Future<FastPathCandidate?> _resolveFast(
      String target, String raw, String convId, ConversationMemory? mem) async =>
      await fastPath!.resolve(text: target, conversationId: convId, memoryOverride: mem) ??
      (target != raw
          ? await fastPath!.resolve(text: raw, conversationId: convId, memoryOverride: mem)
          : null);

  Future<PersonalTurnReply?> _resolveExternalKnowledge(
      String query, {required bool isFast}) async {
    final external = await knowledgeRouter!.fetchKnowledge(query);
    if (!external.hasFacts || external.rawKnowledge.trim().isEmpty) return null;
    final styled = styleFormatter.formatKnowledge(rawFacts: external.rawKnowledge, query: query);
    return PersonalTurnReply(
      text: styled.text,
      understanding: styled.understanding,
      suggestions: styled.suggestions,
      isFast: isFast,
    );
  }
}

