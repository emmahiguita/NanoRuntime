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

part 'tool_routed_conversation_reply_composer.part.dart';

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
    this.previewOnly = false,
  });

  final NotificationObject notification;
  final ConversationDecisionContext? decisionContext;
  // Vista previa: no consume el inbox ni habilita un envío al contacto.
  final bool previewOnly;

  @override
  Map<String, Object?> toRedactedMap() => {
    'eventKey': notification.key,
    'packageName': notification.packageName,
    'textLength': notification.text.length,
    'previewOnly': previewOnly,
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

  /// Delega al compositor real, diferenciando eventos de vistas previas manuales.
  static RegisteredTool createComposePersonalTool({
    required ConversationReplyComposer composer,
  }) {
    final tool = ActionToolAdapter<ComposePersonalReplyArguments, Object?>(
      definition: const ToolDefinition(
        id: 'conversation.composePersonal',
        version: 1,
        displayName: 'Componer respuesta personal',
        description: 'Ejecuta el compositor conversacional canónico existente.',
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
        timeout: Duration(seconds: 180),
        tags: {'conversation', 'personal', 'composer'},
      ),
      onExecute: (context) async {
        final startedAt = DateTime.now();
        // No traduce una solicitud de borrador a un evento automático.
        final args = context.arguments;
        final Object? output = args.previewOnly
            ? await composer.composeSuggestions(
                args.notification,
                decisionContext: args.decisionContext,
              )
            : await composer.compose(
                context.arguments.notification,
                decisionContext: context.arguments.decisionContext,
              );
        final draft = output is ConversationDraftResult ? output : null;
        return ToolResult.success(
          output: output,
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
