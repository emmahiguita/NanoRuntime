import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/action_tool_adapter.dart';
import 'package:nanoai/features/automation/engine/messaging/reply_transport.dart';
import 'package:nanoai/features/automation/engine/orchestration/commit_guard.dart';

import 'whatsapp_reply_arguments.dart';

export 'whatsapp_reply_arguments.dart';

/// Herramienta ejecutable del agente para responder en WhatsApp (< 160 LOC).
///
/// **QUÉ HACE:**
/// Implementa la acción `whatsapp.reply` que despacha respuestas a través del
/// `ReplyTransport` y la capacidad `RemoteInput` de notificaciones de Android.
///
/// **CÓMO FUNCIONA:**
/// - Valida que la capacidad `ReplyCapabilityRef` siga siendo utilizable (`isUsable`).
/// - Invoca `transport.dispatch` transmitiendo el texto con confirmación.
/// - Si hay un `echoVerifier`, confirma que el mensaje fue emitido exitosamente.
///
/// **POR QUÉ:**
/// Permite que tanto el orquestador determinista como el LLM ejecuten respuestas
/// físicas en el canal WhatsApp respetando las políticas de seguridad y permisos de Android.
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
