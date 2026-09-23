// conversation_reply_composer.dart
//
// QUÉ HACE:
// Orquestador canónico de composición conversacional para WhatsApp (Personal y Negocios).
//
// CÓMO FUNCIONA:
// 1. Resuelve turnos comerciales de WhatsApp Business con BusinessConversationResolver (<5ms, 0 tokens).
// 2. Evalúa FastPath determinista para turnos cotidianos en chat personal.
// 3. Consulta PersonaStyleResolver con FTS4 local para imitar el tono real del dueño.
// 4. Aplica TurnKnowledgeRouter si el mensaje requiere hechos contextuales externos (Web).
// 5. Infiere mediante LLM local con control térmico (< CRITICAL) y fallback garantizado.
//
// POR QUÉ:
// Aplica Clean Architecture y SOLID (< 180 líneas) garantizando atención comercial completa y fluida.

library;

import 'package:flutter/foundation.dart' show debugPrint;
import '../business/business_conversation_resolver.dart';
import '../business/business_facts.dart';
import '../language/pragmatic_fast_path.dart';
import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../messaging/conversation_memory.dart';
import '../messaging/conversation_context_resolver.dart';
import '../messaging/messaging_package.dart';
import '../messaging/tone_profile.dart';
import '../notifications/conversation_understanding.dart';
import '../notifications/notification_draft_writer.dart';
import '../notifications/notification_object.dart';
import '../../chess/application/chess_referee_service.dart';
import '../../personal_agent/application/conversation_decision_engine.dart';
import '../../personal_agent/domain/conversation_decision.dart';
import 'conversation_reply_composer_models.dart';
import 'personal_style_formatter.dart';
import 'persona_style_resolver.dart';
import 'turn_context_router.dart';
import 'turn_knowledge_router.dart';

export 'conversation_reply_composer_models.dart';

final class RuntimeConversationReplyComposer implements ConversationReplyComposer {
  RuntimeConversationReplyComposer({
    required NotificationDraftSource draftSource,
    PragmaticFastPath? fastPath,
    PersonaStyleResolver? styleResolver,
    TurnKnowledgeRouter? knowledgeRouter,
    BusinessConversationResolver? businessResolver,
    BusinessFacts Function()? factsSource,
    ToneProfile Function()? toneSource,
    PersonalStyleFormatter styleFormatter = const RuntimePersonalStyleFormatter(),
    TurnContextRouter turnRouter = const TurnContextRouter(),
    ConversationMemoryStore? memoryStore,
    ConversationDecisionEngine decisionEngine = const ConversationDecisionEngine(),
    ChessRefereeService? chessService,
    Future<int> Function()? thermalStatus,
    ConversationDecisionContext Function(NotificationObject)? decisionContext,
  }) : _draftSource = draftSource,
       _fastPath = fastPath,
       _styleResolver = styleResolver,
       _knowledgeRouter = knowledgeRouter,
       _businessResolver = businessResolver,
       _factsSource = factsSource,
       _toneSource = toneSource,
       _styleFormatter = styleFormatter,
       _turnRouter = turnRouter,
       _memoryStore = memoryStore,
       _decisionEngine = decisionEngine,
       _chessService = chessService,
       _thermalStatus = thermalStatus,
       _decisionContext = decisionContext;

  final NotificationDraftSource _draftSource;
  final PragmaticFastPath? _fastPath;
  final PersonaStyleResolver? _styleResolver;
  final TurnKnowledgeRouter? _knowledgeRouter;
  final BusinessConversationResolver? _businessResolver;
  final BusinessFacts Function()? _factsSource;
  final ToneProfile Function()? _toneSource;
  final PersonalStyleFormatter _styleFormatter;
  final TurnContextRouter _turnRouter;
  final ConversationMemoryStore? _memoryStore;
  final ConversationDecisionEngine _decisionEngine;
  final ChessRefereeService? _chessService;
  final Future<int> Function()? _thermalStatus;
  final ConversationDecisionContext Function(NotificationObject)? _decisionContext;

  @override
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    final identity = resolveConversationIdentity(notification);
    final conversationId = identity.key.id;
    final resContext = decisionContext ?? _decisionContext?.call(notification) ?? const ConversationDecisionContext();

    final memory = ConversationContextResolver.resolve(store: _memoryStore, conversationId: conversationId, notification: notification);
    final isBusiness = notification.packageName == MessagingPackage.whatsappBusiness;
    final analysis = _turnRouter.analyze(notification: notification, memory: memory, isBusinessChannel: isBusiness);

    // 0. Chess Referee Engine: Atención determinista de ajedrez (<5ms, 0 tokens).
    if (_chessService != null &&
        _chessService.shouldHandleMessage(
          conversationId: conversationId,
          text: analysis.targetText,
        )) {
      final chessRes = await _chessService.processMessage(
        conversationId: conversationId,
        senderJid: notification.sender,
        senderName: notification.sender.isNotEmpty
            ? notification.sender
            : notification.title,
        text: analysis.targetText,
        isGroup: notification.isGroup,
      );
      if (chessRes.handled && chessRes.replyText.isNotEmpty) {
        final u = ConversationUnderstanding(
          reply: chessRes.replyText,
          intent: 'chess_game',
          requiresAction: false,
          missingFacts: const [],
          options: chessRes.isGameOver
              ? const ['!ajedrez']
              : const ['!tablero', '!rendirse'],
        );
        return _pack(chessRes.replyText, u, const [], resContext, conversationId, true);
      }
    }

    // 1. Canal Comercial: BusinessConversationResolver atiende catálogo, envíos, pagos y saludos de inmediato.
    if (isBusiness && _businessResolver != null) {
      final facts = _factsSource?.call() ?? const BusinessFacts();
      final tone = _toneSource?.call() ?? const ToneProfile();
      final bReply = _businessResolver.resolve(message: analysis.fullText, facts: facts, tone: tone);
      if (bReply != null && bReply.text.isNotEmpty) {
        final u = ConversationUnderstanding(reply: bReply.text, intent: 'business_commercial', requiresAction: false, missingFacts: const [], options: bReply.suggestions);
        return _pack(bReply.text, u, bReply.suggestions, resContext, conversationId, true);
      }
    }

    // 2. Pragmatic Fast Path: Atajos deterministas para chat cotidiano (<5ms, 0 tokens).
    if (analysis.isFastPathEligible && _fastPath != null) {
      final fast = await _fastPath.resolve(text: analysis.targetText, conversationId: conversationId, memoryOverride: memory) ??
          (analysis.targetText != notification.text ? await _fastPath.resolve(text: notification.text, conversationId: conversationId, memoryOverride: memory) : null);
      if (fast != null) {
        return _pack(fast.reply, fast.understanding, fast.suggestions, resContext, conversationId, true);
      }
    }

    // 3. Persona Style Resolver: Respuestas del dueño vía FTS4.
    final directEligible = !analysis.hasContextualContinuity && !analysis.targetComplexity.isNarrative && !analysis.targetComplexity.isContextual && !analysis.targetComplexity.isComplex;
    if (!isBusiness && directEligible && _styleResolver != null) {
      final match = await _styleResolver.resolve(text: analysis.targetText, conversationId: conversationId, minConfidence: 0.70);
      if (match != null) {
        return _pack(match.reply, match.understanding, match.suggestions, resContext, conversationId, true);
      }
    }

    // 4. Knowledge Router: Búsqueda fáctica externa.
    if (!isBusiness && _knowledgeRouter != null && _knowledgeRouter.needsExternalKnowledge(analysis.targetText)) {
      final ext = await _knowledgeRouter.fetchKnowledge(analysis.targetText);
      if (ext.hasFacts && ext.rawKnowledge.trim().isNotEmpty) {
        final styled = _styleFormatter.formatKnowledge(rawFacts: ext.rawKnowledge, query: analysis.targetText);
        return _pack(styled.text, styled.understanding, styled.suggestions, resContext, conversationId, true);
      }
    }

    // 5. Control térmico: CRITICAL+ suprime inferencia pesada.
    final thermal = await _thermalStatus?.call();
    if (thermal != null && thermal >= 4) {
      debugPrint('[conversation-compose] thermal $thermal: suprimido');
      return null;
    }

    // 6. Inferencia contextual LLM (Fallback / Casos complejos).
    final draft = await _draftSource(notification);
    if (draft != null && draft.hasReply) {
      return _pack(draft.reply, draft.understanding, draft.understanding.options, resContext, conversationId, false);
    }

    // 7. Fallback honesto final.
    if (isBusiness && _businessResolver != null) {
      final facts = _factsSource?.call() ?? const BusinessFacts();
      final tone = _toneSource?.call() ?? const ToneProfile();
      final bFallback = _businessResolver.resolve(message: analysis.fullText, facts: facts, tone: tone);
      if (bFallback != null) {
        final u = ConversationUnderstanding(reply: bFallback.text, intent: 'business_fallback', requiresAction: false, missingFacts: const [], options: bFallback.suggestions);
        return _pack(bFallback.text, u, bFallback.suggestions, resContext, conversationId, true);
      }
    } else {
      if (_styleResolver != null) {
        final rel = await _styleResolver.resolve(text: analysis.targetText, conversationId: conversationId, minConfidence: 0.50);
        if (rel != null) return _pack(rel.reply, rel.understanding, rel.suggestions, resContext, conversationId, true);
      }
      if (_fastPath != null) {
        final fbFast = await _fastPath.resolve(text: analysis.targetText, conversationId: conversationId, memoryOverride: memory);
        if (fbFast != null) return _pack(fbFast.reply, fbFast.understanding, fbFast.suggestions, resContext, conversationId, true);
      }
    }
    return null;
  }

  @override
  Future<List<String>> composeSuggestions(NotificationObject notif, {int maxSuggestions = 3, ConversationDecisionContext? decisionContext}) async {
    final res = await compose(notif, decisionContext: decisionContext);
    if (res == null || !res.hasReply) return const [];
    return res.suggestions.take(maxSuggestions).toList();
  }

  ConversationDraftResult _pack(String reply, ConversationUnderstanding u, List<String> suggs, ConversationDecisionContext ctx, String convId, bool isFast) {
    return packConversationDraftResult(reply: reply, understanding: u, suggestions: suggs, context: ctx, conversationId: convId, isFastPath: isFast, decisionEngine: _decisionEngine);
  }
}
