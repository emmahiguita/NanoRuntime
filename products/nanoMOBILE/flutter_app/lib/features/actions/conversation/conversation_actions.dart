import 'package:nanoai/core/tools/application/tool_router.dart';
import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/action_tool_adapter.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_reply_composer.dart';
import 'package:nanoai/features/automation/engine/language/turn_complexity_classifier.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/engine/messaging/incoming_message.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_decision.dart';

final class ClassifyConversationArguments implements ToolArguments {
  const ClassifyConversationArguments(this.text);
  factory ClassifyConversationArguments.fromMap(Map<String, dynamic> raw) {
    final text = '${raw['text'] ?? ''}'.trim();
    if (text.isEmpty) throw const FormatException('text es obligatorio.');
    return ClassifyConversationArguments(text);
  }

  final String text;
  @override
  Map<String, Object?> toRedactedMap() => {'textLength': text.length};
}

final class ConversationClassificationSnapshot {
  const ConversationClassificationSnapshot({
    required this.isComplex,
    required this.isSocialMinimal,
    required this.isNarrative,
    required this.isContextual,
    required this.isPureSocial,
  });
  final bool isComplex;
  final bool isSocialMinimal;
  final bool isNarrative;
  final bool isContextual;
  final bool isPureSocial;
}

final class ComposePersonalReplyArguments implements ToolArguments {
  const ComposePersonalReplyArguments({
    required this.notification,
    required this.decisionContext,
  });

  final NotificationObject notification;
  final ConversationDecisionContext decisionContext;

  @override
  Map<String, Object?> toRedactedMap() => {
    'eventKey': notification.key,
    'packageName': notification.packageName,
    'textLength': notification.text.length,
  };
}

abstract final class ConversationActions {
  static RegisteredTool createClassifyTool({
    TurnComplexityClassifier? classifier,
  }) {
    final active = classifier ?? const TurnComplexityClassifier();
    final tool =
        ActionToolAdapter<
          ClassifyConversationArguments,
          ConversationClassificationSnapshot
        >(
          definition: const ToolDefinition(
            id: 'conversation.classify',
            version: 1,
            displayName: 'Clasificar turno',
            description:
                'Clasifica complejidad y pragmática sin efectos secundarios.',
            category: ToolCategory.domainAction,
            risk: ToolRiskLevel.readOnly,
            sideEffect: ToolSideEffect.none,
            requiredPermissions: [ToolPermission.messagesRead],
            allowedExecutionModes: [
              ToolExecutionMode.foreground,
              ToolExecutionMode.background,
              ToolExecutionMode.headless,
            ],
            inputSchema: {
              'required': ['text'],
              'properties': {'text': 'string'},
            },
            tags: {'conversation', 'classification', 'read'},
          ),
          onExecute: (context) async {
            final result = active.classify(context.arguments.text);
            return ToolResult.success(
              output: ConversationClassificationSnapshot(
                isComplex: result.isComplex,
                isSocialMinimal: result.isSocialMinimal,
                isNarrative: result.isNarrative,
                isContextual: result.isContextual,
                isPureSocial: result.eligibleForSocialPrompt,
              ),
              executionId: context.executionId,
            );
          },
        );
    return TypedToolRegistration(
      tool: tool,
      decoder: ClassifyConversationArguments.fromMap,
    );
  }

  /// Adapter over the canonical production composer. It reuses FastPath,
  /// memory, style retrieval, knowledge routing, LLM and DecisionEngine.
  static RegisteredTool createComposePersonalTool({
    required ConversationReplyComposer composer,
  }) {
    final tool =
        ActionToolAdapter<
          ComposePersonalReplyArguments,
          ConversationDraftResult?
        >(
          definition: const ToolDefinition(
            id: 'conversation.composePersonal',
            version: 1,
            displayName: 'Componer respuesta personal',
            description:
                'Ejecuta el compositor conversacional canónico existente.',
            category: ToolCategory.domainAction,
            risk: ToolRiskLevel.readOnly,
            sideEffect: ToolSideEffect.localRead,
            requiredPermissions: [
              ToolPermission.messagesRead,
              ToolPermission.memoryRead,
            ],
            allowedRoles: [AgentCallerRole.personal, AgentCallerRole.system],
            allowedExecutionModes: [
              ToolExecutionMode.foreground,
              ToolExecutionMode.background,
              ToolExecutionMode.headless,
            ],
            tags: {'conversation', 'personal', 'composer'},
          ),
          onExecute: (context) async {
            final startedAt = DateTime.now();
            final draft = await composer.compose(
              context.arguments.notification,
              decisionContext: context.arguments.decisionContext,
            );
            return ToolResult.success(
              output: draft,
              startedAt: startedAt,
              executionId: context.executionId,
              evidence: [
                ToolEvidence(
                  type: ToolEvidenceType.computation,
                  source: 'RuntimeConversationReplyComposer',
                  timestamp: DateTime.now(),
                  data: {
                    'draftProduced': draft?.hasReply == true,
                    'fastPath': draft?.isFastPath == true,
                  },
                ),
              ],
            );
          },
        );
    return TypedToolRegistration(
      tool: tool,
      decoder: (_) => throw const FormatException(
        'conversation.composePersonal solo acepta argumentos tipados internos.',
      ),
    );
  }
}

/// Production bridge: every conversation composition enters the formal
/// ToolRouter while the actual intelligence remains in the existing composer.
final class ToolRoutedConversationReplyComposer
    implements ConversationReplyComposer {
  const ToolRoutedConversationReplyComposer(this.router);

  final ToolRouter router;

  @override
  Future<ConversationDraftResult?> compose(
    NotificationObject notification, {
    ConversationDecisionContext? decisionContext,
  }) async {
    final identity = resolveConversationIdentity(notification);
    final eventId = IncomingMessage.fromNotification(notification).eventId;
    final result = await router.dispatchTyped(
      TypedToolRequest(
        toolId: 'conversation.composePersonal',
        arguments: ComposePersonalReplyArguments(
          notification: notification,
          decisionContext:
              decisionContext ?? const ConversationDecisionContext(),
        ),
        caller: const AgentIdentity(role: AgentCallerRole.system),
        environment: const ToolExecutionEnvironment(
          mode: ToolExecutionMode.background,
          userPresent: false,
        ),
        conversation: ToolConversationIdentity(
          id: identity.key.id,
          platform: notification.packageName,
          participant: notification.sender,
        ),
        correlationId: eventId,
      ),
    );
    if (!result.executionSucceeded) return null;
    return result.output is ConversationDraftResult
        ? result.output as ConversationDraftResult
        : null;
  }

  @override
  Future<List<String>> composeSuggestions(
    NotificationObject notification, {
    int maxSuggestions = 3,
    ConversationDecisionContext? decisionContext,
  }) async {
    final result = await compose(
      notification,
      decisionContext: decisionContext,
    );
    if (result == null) return const [];
    final candidates = result.suggestions.isEmpty
        ? <String>[result.text]
        : result.suggestions;
    return candidates.take(maxSuggestions).toList(growable: false);
  }
}
