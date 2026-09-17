/// CANONICAL CONVERSATION COMPOSER
///
/// Unifica la comprensión y composición conversacional para WhatsApp:
/// modo automático (RuleDispatcher), modo sugerencias (PendingReplyStore),
/// y modo manual (NotificationAutomationSection / Responder mensajes).
///
/// Cumple Clean Architecture: pertenece a `engine/conversation/` y NUNCA
/// importa capas superiores (`application` o `presentation`).
/// Modularizado bajo SOLID (< 295 líneas).
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../language/language_assist.dart';
import '../language/pragmatic_fast_path.dart';
import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../messaging/conversation_memory.dart';
import '../messaging/messaging_package.dart';
import '../notifications/conversation_understanding.dart';
import '../notifications/notification_draft_writer.dart';
import '../notifications/notification_object.dart';
import '../../personal_agent/application/conversation_decision_engine.dart';
import '../../personal_agent/domain/conversation_agent_role.dart';
import '../../personal_agent/domain/conversation_decision.dart';
import 'personal_style_formatter.dart';
import 'persona_style_resolver.dart';
import 'turn_context_router.dart';
import 'turn_knowledge_router.dart';

/// Resultado estructurado de la composición de respuesta.
final class ConversationDraftResult {
  final String text;
  final ConversationUnderstanding understanding;
  final ConversationDecision decision;
  final ConversationAgentRole role;
  final String conversationId;
  final bool isFastPath;
  final bool isRepaired;
  final List<String> suggestions;

  const ConversationDraftResult({
    required this.text,
    required this.understanding,
    required this.decision,
    required this.role,
    required this.conversationId,
    this.suggestions = const [],
    this.isFastPath = false,
    this.isRepaired = false,
  });

  bool get hasReply => text.trim().isNotEmpty;
}

/// Contrato único de composición conversacional para toda la aplicación.
abstract interface class ConversationReplyComposer {
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  });

  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  });
}

/// Implementación concreta de producción de [ConversationReplyComposer].
final class RuntimeConversationReplyComposer
    implements ConversationReplyComposer {
  RuntimeConversationReplyComposer({
    required NotificationDraftSource draftSource,
    PragmaticFastPath? fastPath,
    PersonaStyleResolver? styleResolver,
    TurnKnowledgeRouter? knowledgeRouter,
    PersonalStyleFormatter styleFormatter = const RuntimePersonalStyleFormatter(),
    TurnContextRouter turnRouter = const TurnContextRouter(),
    ConversationMemoryStore? memoryStore,
    ConversationDecisionEngine decisionEngine = const ConversationDecisionEngine(),
    Future<int> Function()? thermalStatus,
    ConversationDecisionContext Function(NotificationObject)? decisionContext,
  }) : _draftSource = draftSource,
       _fastPath = fastPath,
       _styleResolver = styleResolver,
       _knowledgeRouter = knowledgeRouter,
       _styleFormatter = styleFormatter,
       _turnRouter = turnRouter,
       _memoryStore = memoryStore,
       _decisionEngine = decisionEngine,
       _thermalStatus = thermalStatus,
       _decisionContext = decisionContext;

  final NotificationDraftSource _draftSource;
  final PragmaticFastPath? _fastPath;
  final PersonaStyleResolver? _styleResolver;
  final TurnKnowledgeRouter? _knowledgeRouter;
  final PersonalStyleFormatter _styleFormatter;
  final TurnContextRouter _turnRouter;
  final ConversationMemoryStore? _memoryStore;
  final ConversationDecisionEngine _decisionEngine;
  final Future<int> Function()? _thermalStatus;
  final ConversationDecisionContext Function(NotificationObject)?
  _decisionContext;

  @override
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    final identity = resolveConversationIdentity(notification);
    final conversationId = identity.key.id;
    final resolvedContext =
        decisionContext ??
        _decisionContext?.call(notification) ??
        const ConversationDecisionContext();

    final memory = _memoryStore?.memoryFor(conversationId);
    final isBusiness =
        notification.packageName == MessagingPackage.whatsappBusiness;

    final analysis = _turnRouter.analyze(
      notification: notification,
      memory: memory,
      isBusinessChannel: isBusiness,
    );

    debugPrint(
      '[conversation-compose] conv=${conversationId.length <= 8 ? conversationId : conversationId.substring(0, 8)} '
      'target="${analysis.targetText}" ack=${analysis.isShortAcknowledgment} '
      'continuity=${analysis.hasContextualContinuity} fast=${analysis.isFastPathEligible}',
    );

    // 1. Pragmatic Fast Path: Atajos cotidianos deterministas (<5ms, 0 LLM).
    if (analysis.isFastPathEligible && _fastPath != null) {
      final fast = await _fastPath.resolve(text: analysis.targetText, conversationId: conversationId) ??
          (analysis.targetText != notification.text
              ? await _fastPath.resolve(text: notification.text, conversationId: conversationId)
              : null);
      if (fast != null) {
        return _pack(fast.reply, fast.understanding, fast.suggestions, resolvedContext, conversationId, true);
      }
    }

    // 2. Persona Style Resolver: Recuperación directa FTS4 de respuestas del dueño.
    if (!isBusiness && _styleResolver != null) {
      final match = await _styleResolver.resolve(
        text: analysis.targetText,
        conversationId: conversationId,
        minConfidence: 0.70,
      );
      if (match != null) {
        return _pack(match.reply, match.understanding, match.suggestions, resolvedContext, conversationId, true);
      }
    }

    // 3. Knowledge Router: Información fáctica externa expresada en estilo del dueño.
    if (!isBusiness &&
        _knowledgeRouter != null &&
        _knowledgeRouter.needsExternalKnowledge(analysis.targetText)) {
      final ext = await _knowledgeRouter.fetchKnowledge(analysis.targetText);
      if (ext.hasFacts && ext.rawKnowledge.trim().isNotEmpty) {
        final styled = _styleFormatter.formatKnowledge(
          rawFacts: ext.rawKnowledge,
          query: analysis.targetText,
        );
        return _pack(styled.text, styled.understanding, styled.suggestions, resolvedContext, conversationId, true);
      }
    }

    // 4. Control térmico: CRITICAL+ (>=4) suprime inferencia pesada.
    final thermal = await _thermalStatus?.call();
    if (thermal != null && thermal >= 4) {
      debugPrint('[conversation-compose] thermal $thermal (critical+): suprimido');
      return null;
    }

    // 5. Inferencia contextual LLM (Fallback / Casos complejos).
    final draft = await _draftSource(notification);
    if (draft != null && draft.hasReply) {
      return _pack(draft.reply, draft.understanding, draft.understanding.options, resolvedContext, conversationId, false);
    }

    // 6. Fallback honesto sin LLM: estilo flexible o fast path relajado.
    if (!isBusiness) {
      if (_styleResolver != null) {
        final relaxed = await _styleResolver.resolve(
          text: analysis.targetText,
          conversationId: conversationId,
          minConfidence: 0.50,
        );
        if (relaxed != null) {
          return _pack(relaxed.reply, relaxed.understanding, relaxed.suggestions, resolvedContext, conversationId, true);
        }
      }

      if (_fastPath != null) {
        final fallbackFast = await _fastPath.resolve(text: analysis.targetText, conversationId: conversationId);
        if (fallbackFast != null) {
          return _pack(fallbackFast.reply, fallbackFast.understanding, fallbackFast.suggestions, resolvedContext, conversationId, true);
        }
      }
    }

    debugPrint('[conversation-compose] sin borrador producido por ninguna vía');
    return null;
  }

  @override
  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  }) async {
    final res = await compose(notification, decisionContext: decisionContext);
    if (res == null || !res.hasReply) return const [];
    return res.suggestions.take(maxSuggestions).toList();
  }

  ConversationDraftResult _pack(
    String reply,
    ConversationUnderstanding understanding,
    List<String> suggestions,
    ConversationDecisionContext context,
    String conversationId,
    bool isFastPath,
  ) {
    final cleaned = LanguageAssistService.safeCleanOutput(reply);
    final decision = _decisionEngine.decide(
      understanding: understanding,
      context: context,
    );
    final isRepaired =
        decision.repairedText != null && decision.repairedText!.trim().isNotEmpty;
    final finalText = isRepaired ? decision.repairedText!.trim() : cleaned.trim();

    final resultSuggestions = <String>[finalText];
    for (final s in suggestions) {
      final cleanS = LanguageAssistService.safeCleanOutput(s);
      if (cleanS.isNotEmpty && !resultSuggestions.contains(cleanS)) {
        resultSuggestions.add(cleanS);
      }
      if (resultSuggestions.length >= 3) break;
    }

    return ConversationDraftResult(
      text: finalText,
      understanding: understanding,
      decision: decision,
      role: context.agentRole,
      conversationId: conversationId,
      suggestions: resultSuggestions,
      isFastPath: isFastPath,
      isRepaired: isRepaired,
    );
  }
}
