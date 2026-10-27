import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/tools/application/tool_policy_gate.dart';
import 'package:nanoai/core/tools/application/tool_registry.dart';
import 'package:nanoai/core/tools/application/tool_router.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/infrastructure/shared_preferences_tool_audit_trail.dart';
import 'package:nanoai/features/actions/conversation/conversation_actions.dart';
import 'package:nanoai/features/actions/personal/personal_actions.dart';
import 'package:nanoai/features/actions/whatsapp/whatsapp_reply_action.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/business/business_conversation_resolver.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/conversation/persona_style_resolver.dart';
import 'package:nanoai/features/automation/engine/conversation/personal_style_formatter.dart';
import 'package:nanoai/features/automation/engine/conversation/turn_knowledge_router.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart' show ToolCall, ToolExecutionStatus;
import 'package:nanoai/features/automation/engine/language/language_assist.dart';
import 'package:nanoai/features/automation/engine/language/semantic_similarity_engine.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_tool.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_tool_projection.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart' show conversationHubVersionProvider;
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart' show resolveConversationIdentity;
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_transport.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_engine.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_pipeline.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_decision_engine.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_ownership_policy.dart';
import 'package:nanoai/features/automation/personal_agent/application/hybrid_retrieval_scorer.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_retriever.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_conversation_resolver.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_owner.dart';
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import 'package:nanoai/features/skills/personal_agent/respond_personal_whatsapp_skill.dart';

import '../domain/automation_goal.dart' show AutomationOptions;
import 'automation_coordinator_provider.dart';
import 'conversation_decision_context_builder.dart';

/// QUÉ HACE: Expone el motor semántico ligero y el resolvedor de estilo personal.
/// CÓMO FUNCIONA: Usa `ref.read` para mantener instancias estables por contenedor.
/// POR QUÉ: Evita que reconstrucciones reactivas invaliden `Ref` en turnos asíncronos.
final semanticSimilarityEngineProvider = Provider<SemanticSimilarityEngine>(
  (ref) => const LightweightSemanticSimilarityEngine(),
);

final personaStyleResolverProvider = Provider<PersonaStyleResolver>((ref) {
  return RuntimePersonaStyleResolver(
    retriever: PersonaRetriever(
      scorer: HybridRetrievalScorer(
        similarityEngine: ref.read(semanticSimilarityEngineProvider),
      ),
    ),
  );
});

/// QUÉ HACE: Enruta consultas factuales externas (BrowserAi / MCP read tools).
/// CÓMO FUNCIONA: Usa `ref.read` sobre `browserAiGatewayProvider` y `mcpConnectionRegistryProvider`.
/// POR QUÉ: Evita que `notifyListeners` de `McpConnectionRegistry` deje este provider en
/// `_mustRecomputeState` (outdated) cuando no tiene UI observándolo directamente.
final turnKnowledgeRouterProvider = Provider<TurnKnowledgeRouter>((ref) {
  final router = RuntimeTurnKnowledgeRouter(
    browserAiGateway: ref.read(browserAiGatewayProvider),
    mcpConnectionRegistry: ref.read(mcpConnectionRegistryProvider),
    mcpKnowledgeToolCaller: (tool, arguments) async {
      if (const McpToolProjection().toNanoTool(tool).category != McpToolCategory.read) {
        return null;
      }
      final outcome = await ref.read(agentDispatcherProvider).runToolGuarded(
        ToolCall(tool: 'mcp.read', args: {'mcpTool': tool.qualifiedName, ...arguments}),
        humanInitiated: false,
      );
      if (outcome.executionStatus != ToolExecutionStatus.completed &&
          outcome.executionStatus != ToolExecutionStatus.completedUnverified) {
        return null;
      }
      final response = outcome.feedback.trim();
      if (response.isEmpty || response.startsWith('[mcpError]') || response.startsWith('[tool]')) {
        return null;
      }
      return response;
    },
  );
  ref.onDispose(router.dispose);
  return router;
});

final personalConversationResolverProvider = Provider<PersonalConversationResolver>((ref) {
  return PersonalConversationResolver(
    knowledgeRouter: ref.read(turnKnowledgeRouterProvider),
    styleFormatter: const RuntimePersonalStyleFormatter(),
  );
});

/// QUÉ HACE: Construye el compositor conversacional canónico y su router de tools.
/// CÓMO FUNCIONA: Lee hechos de negocio, perfil de tono y contexto de decisión vía `ref.read`.
/// POR QUÉ: Garantiza que los closures nunca disparen `ProviderElementBase._assertNotOutdated`.
final canonicalConversationReplyComposerProvider = Provider<ConversationReplyComposer>((ref) {
  return RuntimeConversationReplyComposer(
    draftSource: ref.read(notificationDraftSourceProvider),
    personalResolver: ref.read(personalConversationResolverProvider),
    businessResolver: const BusinessConversationResolver(),
    factsSource: () => ref.read(businessFactsNotifierProvider),
    toneSource: () => ref.read(businessToneProfileNotifierProvider),
    memoryStore: ref.read(conversationMemoryStoreProvider),
    decisionEngine: const ConversationDecisionEngine(),
    thermalStatus: () => LanguageAssistService().thermalStatus(),
    decisionContext: (notif) => buildConversationDecisionContext(ref, notif),
  );
});

final formalToolRouterProvider = Provider<ToolRouter>((ref) {
  final registry = ToolRegistry();
  final router = ToolRouter(
    registry: registry,
    policyGate: ToolPolicyGate(
      registry: registry,
      permissionProvider: const StaticPermissionProvider({
        ToolPermission.messagesRead,
        ToolPermission.memoryRead,
        ToolPermission.notificationReply,
      }),
    ),
    auditTrail: const SharedPreferencesToolAuditTrail(),
  );
  registry.register(ConversationActions.createClassifyTool());
  registry.register(PersonalActions.createGetStyleTool());
  registry.register(PersonalActions.createFindExamplesTool());
  registry.register(
    ConversationActions.createComposePersonalTool(
      composer: ref.read(canonicalConversationReplyComposerProvider),
    ),
  );
  registry.register(
    WhatsAppActions.createReplyTool(
      transport: NotificationReplyTransport(NanoRuntimeApi.instance),
    ),
  );
  registry.register(RespondPersonalWhatsAppSkill.createSkill(router: router));
  registry.freeze();
  return router;
});

final conversationReplyComposerProvider = Provider<ConversationReplyComposer>((ref) {
  return ToolRoutedConversationReplyComposer(ref.read(formalToolRouterProvider));
});

/// QUÉ HACE: Ensambla el `RulePipeline` principal (notificación → dedupe → match → dispatch).
/// CÓMO FUNCIONA: Inyecta stores singletons con `ref.read` para que el `RulePipeline`
/// retenido por `NotificationEventRouter` conserve un `Ref` válido toda la sesión.
/// POR QUÉ: Elimina el `_AssertionError` (`_assertNotOutdated`) en `cold_start_snapshot`.
final rulePipelineProvider = Provider<RulePipeline>((ref) {
  return RulePipeline(
    registry: ref.read(ruleRegistryProvider),
    engine: const RuleEngine(),
    dedupe: ref.read(eventDedupeStoreProvider),
    memory: ref.read(conversationMemoryStoreProvider),
    assignments: ref.read(conversationAssignmentStoreProvider),
    rateLimiter: ref.read(contactRateLimiterProvider),
    readiness: ref.read(automationStoresHydratedProvider),
    supersedeGuard: ref.read(turnSupersedeGuardProvider),
    allowsNotification: (notification) {
      final settings = ref.read(settingsProvider);
      final isWhatsApp =
          notification.packageName == MessagingPackage.whatsapp ||
          notification.packageName == MessagingPackage.whatsappBusiness;
      if (!isWhatsApp || settings.waTargetContactsMode != 'selected') return true;
      final identity = resolveConversationIdentity(notification);
      final owner = ConversationOwnershipPolicy.ownershipForNotification(
        store: ref.read(conversationOwnershipStoreProvider),
        conversationId: identity.key.id,
        notification: notification,
      );
      return owner?.owner == ConversationOwner.bot;
    },
    allowsStyleLearning: (sender, conversationId) => ref
        .read(personaContextProvider)
        .allowsStyleLearningFor(sender, conversationId: conversationId),
    onInboundMessage: (_) {
      final notifier = ref.read(conversationHubVersionProvider.notifier);
      notifier.state = notifier.state + 1;
    },
    dispatcher: RuleDispatcher(
      (goal, {AutomationOptions? options}) =>
          ref.read(automationCoordinatorProvider).execute(goal, options: options),
      composer: ref.read(conversationReplyComposerProvider),
      supersedeGuard: ref.read(turnSupersedeGuardProvider),
      replyDelay: () => Duration(seconds: ref.read(settingsProvider).waReplyDelaySeconds),
      pendingReplyStore: ref.read(pendingReplyStoreProvider),
      decisionContext: (notif) => buildConversationDecisionContext(ref, notif),
      notifyLocal: (title, body) =>
          NanoRuntimeApi.instance.notifyRuleEvent(title: title, body: body),
      shareMedia: (path, contact, caption) => const WhatsAppMediaShare()
          .shareFile(path: path, contact: contact, caption: caption),
    ),
  );
});
