// conversation_reply_composer.dart
//
// QUÉ HACE:
// Orquestador canónico de composición conversacional para WhatsApp (Personal y Negocios).
//
// CÓMO FUNCIONA:
// 1. Aísla negocio y persona usando paquete, agente y memoria de conversación.
// 2. Usa solo estilo aprendido y conocimiento recuperado en el canal personal.
// 3. Redacta WhatsApp Business con el modelo contextual y hechos reales.
// 4. Si no hay evidencia ni respuesta real del modelo, no genera un envío.
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
import '../messaging/conversation_agent.dart';
import '../messaging/incoming_message.dart';
import '../messaging/messaging_package.dart';
import '../messaging/tone_profile.dart';
import '../../personal_agent/application/personal_conversation_resolver.dart';
import '../../personal_agent/domain/conversation_agent_role.dart';
import '../notifications/conversation_understanding.dart';
import '../notifications/notification_draft_writer.dart';
import '../notifications/notification_object.dart';
import '../../personal_agent/application/conversation_decision_engine.dart';
import '../../personal_agent/domain/conversation_decision.dart';
import 'conversation_reply_composer_models.dart';
import '../language/dialogue_act_classifier.dart';
import '../messaging/inbound_deduplicator.dart';
import 'dialogue_state_tracker.dart';
import 'semantic_output_gate.dart';
import 'personal_style_formatter.dart';
import 'persona_style_resolver.dart';
import 'turn_context_router.dart';
import 'turn_knowledge_router.dart';

export 'conversation_reply_composer_models.dart';

part 'conversation_reply_flow.dart';
part 'conversation_reply_fallbacks.dart';

final class RuntimeConversationReplyComposer
    implements ConversationReplyComposer {
  RuntimeConversationReplyComposer({
    required NotificationDraftSource draftSource,
    PersonalConversationResolver? personalResolver,
    PragmaticFastPath? fastPath,
    PersonaStyleResolver? styleResolver,
    TurnKnowledgeRouter? knowledgeRouter,
    BusinessConversationResolver? businessResolver,
    BusinessFacts Function()? factsSource,
    ToneProfile Function()? toneSource,
    PersonalStyleFormatter styleFormatter =
        const RuntimePersonalStyleFormatter(),
    TurnContextRouter turnRouter = const TurnContextRouter(),
    ConversationMemoryStore? memoryStore,
    ConversationDecisionEngine decisionEngine =
        const ConversationDecisionEngine(),
    Future<int> Function()? thermalStatus,
    ConversationDecisionContext Function(NotificationObject)? decisionContext,
  }) : _draftSource = draftSource,
       _personalResolver =
           personalResolver ??
            PersonalConversationResolver(
              fastPath: fastPath ?? const PragmaticFastPath(),
              styleResolver: styleResolver,
             knowledgeRouter: knowledgeRouter,
             styleFormatter: styleFormatter,
           ),
       _businessResolver = businessResolver,
       _factsSource = factsSource,
       _toneSource = toneSource,
       _turnRouter = turnRouter,
       _memoryStore = memoryStore,
       _decisionEngine = decisionEngine,
       _thermalStatus = thermalStatus,
       _decisionContext = decisionContext;

  final NotificationDraftSource _draftSource;
  final PersonalConversationResolver _personalResolver;
  final BusinessConversationResolver? _businessResolver;
  final BusinessFacts Function()? _factsSource;
  final ToneProfile Function()? _toneSource;
  final TurnContextRouter _turnRouter;
  final ConversationMemoryStore? _memoryStore;
  final ConversationDecisionEngine _decisionEngine;
  final Future<int> Function()? _thermalStatus;
  final ConversationDecisionContext Function(NotificationObject)?
  _decisionContext;
  final InboundDeduplicator _deduplicator = InboundDeduplicator();
  final SemanticOutputGate _outputGate = const SemanticOutputGate();
  final DialogueStateTracker _dialogueStateTracker = DialogueStateTracker();

  @override
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) => _composeConversation(notification, decisionContext: decisionContext);

  @override
  Future<List<String>> composeSuggestions(
    NotificationObject notif, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  }) async {
    final res = await compose(notif, decisionContext: decisionContext);
    if (res == null || !res.hasReply) return const [];
    return res.suggestions.take(maxSuggestions).toList();
  }
}
