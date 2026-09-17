import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/action_tool_adapter.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_capability.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_transport.dart';
import 'package:nanoai/features/automation/engine/orchestration/commit_guard.dart';

final class WhatsappReplyArguments implements ToolArguments {
  const WhatsappReplyArguments({
    required this.capability,
    required this.text,
    required this.sourceEventId,
    required this.conversationId,
  });

  factory WhatsappReplyArguments.fromMap(Map<String, dynamic> raw) {
    final text = '${raw['text'] ?? ''}'.trim();
    final notificationKey = '${raw['notificationKey'] ?? ''}'.trim();
    final packageName = '${raw['packageName'] ?? ''}'.trim();
    final remoteInputKey = '${raw['remoteInputResultKey'] ?? ''}'.trim();
    final actionIndex = (raw['actionIndex'] as num?)?.toInt() ?? -1;
    final observedAt = (raw['observedAt'] as num?)?.toInt() ?? 0;
    final fingerprint = '${raw['contextFingerprint'] ?? ''}';
    if (text.isEmpty) throw const FormatException('text es obligatorio.');
    if (notificationKey.isEmpty ||
        packageName.isEmpty ||
        remoteInputKey.isEmpty) {
      throw const FormatException(
        'La capacidad RemoteInput observada es incompleta.',
      );
    }
    return WhatsappReplyArguments(
      capability: ReplyCapabilityRef(
        notificationKey: notificationKey,
        packageName: packageName,
        observedAt: observedAt,
        actionIndex: actionIndex,
        remoteInputResultKey: remoteInputKey,
        contextFingerprint: fingerprint,
      ),
      text: text,
      sourceEventId: '${raw['sourceEventId'] ?? ''}',
      conversationId: '${raw['conversationId'] ?? notificationKey}',
    );
  }

  final ReplyCapabilityRef capability;
  final String text;
  final String sourceEventId;
  final String conversationId;

  @override
  Map<String, Object?> toRedactedMap() => {
    'notificationKey': capability.notificationKey,
    'packageName': capability.packageName,
    'actionIndex': capability.actionIndex,
    'observedAt': capability.observedAt,
    'sourceEventId': sourceEventId,
    'conversationId': conversationId,
    'textLength': text.length,
  };
}

abstract final class WhatsAppActions {
  static RegisteredTool createReplyTool({
    required ReplyTransport transport,
    Future<bool> Function(String conversationId, String text)? echoVerifier,
  }) {
    final tool = VerifiableActionToolAdapter<WhatsappReplyArguments, String>(
      definition: const ToolDefinition(
        id: 'whatsapp.reply',
        version: 1,
        displayName: 'Responder en WhatsApp',
        description:
            'Usa el ReplyTransport y la capacidad RemoteInput observada.',
        category: ToolCategory.domainAction,
        risk: ToolRiskLevel.medium,
        sideEffect: ToolSideEffect.communication,
        approvalPolicy: ApprovalPolicy.contextual,
        requiredPermissions: [ToolPermission.notificationReply],
        allowedExecutionModes: [
          ToolExecutionMode.foreground,
          ToolExecutionMode.background,
          ToolExecutionMode.headless,
        ],
        inputSchema: {
          'required': [
            'text',
            'notificationKey',
            'packageName',
            'actionIndex',
            'remoteInputResultKey',
            'observedAt',
          ],
        },
        timeout: Duration(seconds: 10),
        verificationPolicy: ToolVerificationPolicy.required,
        tags: {'whatsapp', 'communication', 'remote-input'},
      ),
      onExecute: (context) async {
        final startedAt = DateTime.now();
        final arguments = context.arguments;
        if (!arguments.capability.isUsable) {
          return ToolResult<String>.failed(
            failure: const ToolFailure(
              code: 'invalid_reply_capability',
              message: 'La capacidad RemoteInput ya no es utilizable.',
            ),
            startedAt: startedAt,
            executionId: context.executionId,
          );
        }
        final send = await transport.dispatch(
          ReplyDispatchRequest(
            capability: arguments.capability,
            text: arguments.text,
            confirmed: context.environment.approvalGranted,
          ),
        );
        final remoteInputEvidence = ToolEvidence(
          type: ToolEvidenceType.remoteInputAccepted,
          source: 'ReplyTransport',
          timestamp: DateTime.now(),
          data: {
            'status': send.status.name,
            'notificationKey': arguments.capability.notificationKey,
            'textLength': arguments.text.length,
          },
          confidence: send.status == SendEvidenceStatus.localSendVerified
              ? 1
              : 0.8,
        );
        return switch (send.status) {
          SendEvidenceStatus.localSendVerified => ToolResult<String>.success(
            output: send.reason,
            verificationStatus: ToolVerificationStatus.verified,
            evidence: [remoteInputEvidence],
            startedAt: startedAt,
            executionId: context.executionId,
          ),
          SendEvidenceStatus.dispatchedUnverified => ToolResult<String>.success(
            output: send.reason,
            verificationStatus: ToolVerificationStatus.dispatched,
            evidence: [remoteInputEvidence],
            startedAt: startedAt,
            executionId: context.executionId,
          ),
          SendEvidenceStatus.outcomeUnknown => ToolResult<String>.success(
            output: send.reason,
            verificationStatus: ToolVerificationStatus.unknown,
            evidence: [remoteInputEvidence],
            startedAt: startedAt,
            executionId: context.executionId,
          ),
          SendEvidenceStatus.notExecuted ||
          SendEvidenceStatus.contextChanged ||
          SendEvidenceStatus.incompleteEvidence => ToolResult<String>.failed(
            failure: ToolFailure(code: send.status.name, message: send.reason),
            verificationStatus: ToolVerificationStatus.failed,
            evidence: [remoteInputEvidence],
            startedAt: startedAt,
            executionId: context.executionId,
          ),
        };
      },
      onVerify: (context, result) async {
        if (result.verificationStatus == ToolVerificationStatus.verified) {
          return ToolVerificationResult(
            status: ToolVerificationStatus.verified,
            evidence: result.evidence,
          );
        }
        if (result.verificationStatus != ToolVerificationStatus.dispatched) {
          return ToolVerificationResult(status: result.verificationStatus);
        }
        final verifier = echoVerifier;
        if (verifier == null) {
          return const ToolVerificationResult(
            status: ToolVerificationStatus.dispatched,
          );
        }
        final observed = await verifier(
          context.arguments.conversationId,
          context.arguments.text,
        );
        if (!observed) {
          return const ToolVerificationResult(
            status: ToolVerificationStatus.dispatched,
          );
        }
        return ToolVerificationResult(
          status: ToolVerificationStatus.verified,
          evidence: [
            ToolEvidence(
              type: ToolEvidenceType.outboundMessageObserved,
              source: 'conversation_echo',
              timestamp: DateTime.now(),
              data: const {'matched': true},
            ),
          ],
        );
      },
    );
    return TypedToolRegistration(
      tool: tool,
      decoder: WhatsappReplyArguments.fromMap,
    );
  }
}
