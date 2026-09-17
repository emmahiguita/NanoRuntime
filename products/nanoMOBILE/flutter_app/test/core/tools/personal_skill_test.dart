import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/tools/application/tool_policy_gate.dart';
import 'package:nanoai/core/tools/application/tool_registry.dart';
import 'package:nanoai/core/tools/application/tool_router.dart';
import 'package:nanoai/core/tools/domain/tool_audit.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/features/actions/conversation/conversation_actions.dart';
import 'package:nanoai/features/actions/whatsapp/whatsapp_reply_action.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_capability.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_transport.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_understanding.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/orchestration/commit_guard.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';
import 'package:nanoai/features/skills/personal_agent/respond_personal_whatsapp_skill.dart';

final class _FakeTransport implements ReplyTransport {
  ReplyDispatchRequest? lastRequest;
  @override
  Future<SendEvidence> dispatch(ReplyDispatchRequest request) async {
    lastRequest = request;
    return const SendEvidence(
      SendEvidenceStatus.dispatchedUnverified,
      'RemoteInput accepted',
    );
  }
}

final class _FakeComposer implements ConversationReplyComposer {
  _FakeComposer(this.draft);
  final ConversationDraftResult draft;
  int calls = 0;

  @override
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    calls++;
    return draft;
  }

  @override
  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  }) async => [draft.text];
}

NotificationObject _notification() => NotificationObject.fromMap({
  'key': 'wa_key_001',
  'packageName': 'com.whatsapp',
  'title': 'Carlos',
  'text': '¿Vas a entrenar hoy?',
  'messageText': '¿Vas a entrenar hoy?',
  'messageTimestamp': 1000,
  'sender': 'Carlos',
  'senderKey': 'carlos',
  'senderUri': '',
  'conversationTitle': 'Carlos',
  'conversationId': 'conv-carlos',
  'shortcutId': 'conv-carlos',
  'locusId': '',
  'accountHint': '',
  'isGroup': false,
  'isSummary': false,
  'postTime': 1000,
  'canReply': true,
  'remoteInputKey': 'key_text_reply',
  'actionIndex': 0,
  'actions': ['reply'],
  'ongoing': false,
});

ConversationDraftResult _draft({
  required String text,
  ConversationDisposition disposition = ConversationDisposition.autoSend,
}) => ConversationDraftResult(
  text: text,
  understanding: ConversationUnderstanding(reply: text),
  decision: ConversationDecision(
    disposition: disposition,
    risk: ConversationRisk.low,
    confidence: 0.95,
    reasons: const ['fixture'],
  ),
  role: ConversationAgentRole.personal,
  conversationId: 'conv-carlos',
  isFastPath: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('respondPersonalWhatsApp production-wrapper skill', () {
    test(
      'uses canonical composer output and propagates child audit identity',
      () async {
        final registry = ToolRegistry();
        final audit = InMemoryToolAuditTrail();
        final transport = _FakeTransport();
        final composer = _FakeComposer(
          _draft(text: 'Sí, voy tipo seis. ¿Te animas?'),
        );
        late ToolRouter router;
        router = ToolRouter(
          registry: registry,
          policyGate: ToolPolicyGate(
            registry: registry,
            permissionProvider: const StaticPermissionProvider({
              ToolPermission.messagesRead,
              ToolPermission.memoryRead,
              ToolPermission.notificationReply,
            }),
          ),
          auditTrail: audit,
        );
        registry.register(
          ConversationActions.createComposePersonalTool(composer: composer),
        );
        registry.register(
          WhatsAppActions.createReplyTool(transport: transport),
        );
        registry.register(
          RespondPersonalWhatsAppSkill.createSkill(router: router),
        );
        registry.freeze();

        final notification = _notification();
        final capability = ReplyCapabilityRef.fromNotification(notification)!;
        final result = await router.dispatchTyped(
          TypedToolRequest(
            toolId: 'respondPersonalWhatsApp',
            arguments: RespondPersonalWhatsAppArguments(
              notification: notification,
              capability: capability,
              decisionContext: const ConversationDecisionContext(),
              conversationId: 'conv-carlos',
              sourceEventId: 'wa-event-718',
            ),
            caller: const AgentIdentity(role: AgentCallerRole.personal),
            environment: const ToolExecutionEnvironment(
              mode: ToolExecutionMode.background,
              userPresent: false,
            ),
            conversation: const ToolConversationIdentity(
              id: 'conv-carlos',
              platform: 'whatsapp',
            ),
            correlationId: 'wa-event-718',
          ),
        );

        expect(result.executionStatus, ToolExecutionStatus.success);
        expect(result.verificationStatus, ToolVerificationStatus.dispatched);
        expect(
          (result.output as RespondPersonalWhatsAppOutput).replyText,
          'Sí, voy tipo seis. ¿Te animas?',
        );
        expect(transport.lastRequest?.text, 'Sí, voy tipo seis. ¿Te animas?');
        expect(composer.calls, 1);

        final records = await audit.recent();
        final parent = records.firstWhere(
          (record) => record.toolId == 'respondPersonalWhatsApp',
        );
        final children = records.where(
          (record) => record.parentExecutionId == parent.executionId,
        );
        expect(
          children.map((record) => record.toolId),
          containsAll(['conversation.composePersonal', 'whatsapp.reply']),
        );
        expect(
          records.every((record) => record.correlationId == 'wa-event-718'),
          isTrue,
        );
      },
    );

    test(
      'conversation hold decision blocks dispatch without approval',
      () async {
        final registry = ToolRegistry();
        final transport = _FakeTransport();
        final composer = _FakeComposer(
          _draft(
            text: 'Borrador sensible',
            disposition: ConversationDisposition.holdForApproval,
          ),
        );
        late ToolRouter router;
        router = ToolRouter(
          registry: registry,
          policyGate: ToolPolicyGate(
            registry: registry,
            permissionProvider: const StaticPermissionProvider({
              ToolPermission.messagesRead,
              ToolPermission.memoryRead,
              ToolPermission.notificationReply,
            }),
          ),
          auditTrail: InMemoryToolAuditTrail(),
        );
        registry.register(
          ConversationActions.createComposePersonalTool(composer: composer),
        );
        registry.register(
          WhatsAppActions.createReplyTool(transport: transport),
        );
        registry.register(
          RespondPersonalWhatsAppSkill.createSkill(router: router),
        );
        registry.freeze();

        final notification = _notification();
        final result = await router.dispatchTyped(
          TypedToolRequest(
            toolId: 'respondPersonalWhatsApp',
            arguments: RespondPersonalWhatsAppArguments(
              notification: notification,
              capability: ReplyCapabilityRef.fromNotification(notification)!,
              decisionContext: const ConversationDecisionContext(),
              conversationId: 'conv-carlos',
              sourceEventId: 'wa-event-hold',
            ),
            caller: const AgentIdentity(role: AgentCallerRole.personal),
            environment: const ToolExecutionEnvironment.foreground(
              userPresent: true,
            ),
          ),
        );
        expect(result.executionStatus, ToolExecutionStatus.requiresApproval);
        expect(transport.lastRequest, isNull);
      },
    );
  });
}
