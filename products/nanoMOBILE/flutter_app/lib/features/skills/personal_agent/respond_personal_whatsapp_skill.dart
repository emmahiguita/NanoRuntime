import 'package:nanoai/core/tools/application/tool_router.dart';
import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/skill_tool_adapter.dart';
import 'package:nanoai/features/actions/conversation/conversation_actions.dart';
import 'package:nanoai/features/actions/whatsapp/whatsapp_reply_action.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_capability.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

final class RespondPersonalWhatsAppArguments implements ToolArguments {
  const RespondPersonalWhatsAppArguments({
    required this.notification,
    required this.capability,
    required this.decisionContext,
    required this.conversationId,
    required this.sourceEventId,
  });

  final NotificationObject notification;
  final ReplyCapabilityRef capability;
  final ConversationDecisionContext decisionContext;
  final String conversationId;
  final String sourceEventId;

  @override
  Map<String, Object?> toRedactedMap() => {
    'eventKey': notification.key,
    'packageName': notification.packageName,
    'conversationId': conversationId,
    'sourceEventId': sourceEventId,
    'textLength': notification.text.length,
  };
}

final class RespondPersonalWhatsAppOutput {
  const RespondPersonalWhatsAppOutput({
    required this.replyText,
    required this.fastPath,
  });
  final String replyText;
  final bool fastPath;
}

abstract final class RespondPersonalWhatsAppSkill {
  static RegisteredTool createSkill({required ToolRouter router}) {
    final tool =
        SkillToolAdapter<
          RespondPersonalWhatsAppArguments,
          RespondPersonalWhatsAppOutput
        >(
          definition: const ToolDefinition(
            id: 'respondPersonalWhatsApp',
            version: 1,
            displayName: 'Responder WhatsApp personal',
            description:
                'Orquesta el compositor conversacional canónico y ReplyTransport.',
            category: ToolCategory.skill,
            risk: ToolRiskLevel.medium,
            sideEffect: ToolSideEffect.communication,
            // La Skill debe poder componer y calcular ConversationDecision en
            // background. La autorización contextual se aplica en la Action
            // whatsapp.reply, después de que autoSend/hold sea conocido.
            approvalPolicy: ApprovalPolicy.never,
            requiredPermissions: [
              ToolPermission.messagesRead,
              ToolPermission.memoryRead,
              ToolPermission.notificationReply,
            ],
            allowedRoles: [AgentCallerRole.personal, AgentCallerRole.system],
            allowedExecutionModes: [
              ToolExecutionMode.foreground,
              ToolExecutionMode.background,
              ToolExecutionMode.headless,
            ],
            timeout: Duration(seconds: 45),
            tags: {'skill', 'whatsapp', 'personal', 'conversation'},
          ),
          onExecute: (context) async {
            final startedAt = DateTime.now();
            final arguments = context.arguments;
            final compose = await router.dispatchTyped(
              TypedToolRequest(
                toolId: 'conversation.composePersonal',
                arguments: ComposePersonalReplyArguments(
                  notification: arguments.notification,
                  decisionContext: arguments.decisionContext,
                ),
                caller: context.caller,
                environment: context.environment,
                conversation: context.conversation,
                parentExecutionId: context.executionId,
                correlationId: context.correlationId ?? arguments.sourceEventId,
              ),
            );
            if (!compose.executionSucceeded) {
              return ToolResult<RespondPersonalWhatsAppOutput>(
                executionStatus: compose.executionStatus,
                verificationStatus: compose.verificationStatus,
                evidence: compose.evidence,
                failure: compose.failure,
                startedAt: startedAt,
                finishedAt: DateTime.now(),
                executionId: context.executionId,
              );
            }
            final draft = compose.output;
            if (draft is! ConversationDraftResult || !draft.hasReply) {
              return ToolResult<RespondPersonalWhatsAppOutput>.failed(
                failure: const ToolFailure(
                  code: 'no_conversational_draft',
                  message:
                      'El compositor canónico no produjo una respuesta segura.',
                ),
                startedAt: startedAt,
                executionId: context.executionId,
              );
            }
            if (!draft.decision.autoSend &&
                !context.environment.approvalGranted) {
              return ToolResult<RespondPersonalWhatsAppOutput>(
                executionStatus: ToolExecutionStatus.requiresApproval,
                verificationStatus: ToolVerificationStatus.notRequired,
                failure: ToolFailure(
                  code: 'conversation_decision_requires_approval',
                  message: draft.decision.reasons.join('; '),
                ),
                startedAt: startedAt,
                finishedAt: DateTime.now(),
                executionId: context.executionId,
              );
            }
            final reply = await router.dispatchTyped(
              TypedToolRequest(
                toolId: 'whatsapp.reply',
                arguments: WhatsappReplyArguments(
                  capability: arguments.capability,
                  text: draft.text,
                  sourceEventId: arguments.sourceEventId,
                  conversationId: arguments.conversationId,
                ),
                caller: context.caller,
                environment: ToolExecutionEnvironment(
                  mode: context.environment.mode,
                  userPresent: context.environment.userPresent,
                  approvalGranted:
                      context.environment.approvalGranted ||
                      draft.decision.autoSend,
                ),
                conversation: context.conversation,
                parentExecutionId: context.executionId,
                correlationId: context.correlationId ?? arguments.sourceEventId,
              ),
            );
            return ToolResult<RespondPersonalWhatsAppOutput>(
              executionStatus: reply.executionStatus,
              verificationStatus: reply.verificationStatus,
              output: reply.executionSucceeded
                  ? RespondPersonalWhatsAppOutput(
                      replyText: draft.text,
                      fastPath: draft.isFastPath,
                    )
                  : null,
              evidence: [...compose.evidence, ...reply.evidence],
              failure: reply.failure,
              startedAt: startedAt,
              finishedAt: DateTime.now(),
              executionId: context.executionId,
            );
          },
        );
    return TypedToolRegistration(
      tool: tool,
      decoder: (_) => throw const FormatException(
        'respondPersonalWhatsApp solo acepta contexto tipado y evidencia Android.',
      ),
    );
  }
}
