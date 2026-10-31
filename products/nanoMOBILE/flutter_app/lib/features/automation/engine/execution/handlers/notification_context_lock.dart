import '../../../../../core/services/nano_runtime_api.dart';
import '../../governance/rule_execution_authority.dart';
import '../agent_executor.dart';
import '../tool_call.dart';
import '../tool_outcome.dart';
import '../tool_registry.dart';
import 'whatsapp_reply_context_lock.dart';

/// Selecciona el validador real del transporte antes de reclamar la acci?n.
/// WhatsApp usa su ventana observada; RemoteInput usa la notificaci?n vigente.
Future<ToolOutcome?> validateNotificationContextLock(
  NanoRuntimeApi runtime,
  AgentExecutor executor,
  ToolCall call,
  ToolDefinition tool, {
  RuleExecutionAuthority? authority,
}) async {
  if (!tool.requiresContextLock) return null;
  if (call.tool == 'whatsapp.send_message' &&
      call.args?['replyInPlace'] == true) {
    return validateWhatsAppReplyContext(call, await executor.snapshot());
  }
  if (call.tool != 'reply_notification') {
    return const ToolOutcome(
      verdict: PolicyVerdict.denied,
      feedback:
          '[contextLockUnavailable] Acción bloqueada: no existe un validador '
          'de contexto para esta herramienta.',
      executionStatus: ToolExecutionStatus.notExecuted,
    );
  }

  final key = call.keyArg;
  if (key == null || key.isEmpty) {
    return const ToolOutcome(
      verdict: PolicyVerdict.denied,
      feedback:
          '[contextChanged] La notificación ya no tiene una identidad válida.',
      executionStatus: ToolExecutionStatus.notExecuted,
    );
  }
  try {
    final status = await runtime.notificationStatus();
    if (status['accessGranted'] != true || status['connected'] != true) {
      return const ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[contextChanged] No se puede revalidar la notificación: el '
            'servicio no está conectado.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }
    final rows = await runtime.listActiveNotifications(limit: 100);
    final current = rows.whereType<Map>().where(
      (row) => '${row['key'] ?? ''}' == key,
    );
    if (current.length != 1 || current.single['canReply'] != true) {
      return const ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[contextChanged] La notificación cambió, desapareció o ya no '
            'admite respuesta. No se envió nada.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }
    if (authority != null) {
      final row = current.single;
      if (!authority.satisfiesPackage('${row['package'] ?? ''}')) {
        return ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[scopeMismatch] La notificación ya no pertenece al paquete '
              'autorizado por la regla (${row['package']}). No se envió nada.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
      if (!authority.satisfiesConversation(
        '${row['sender'] ?? ''}',
        '${row['conversationTitle'] ?? ''}',
      )) {
        return const ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[scopeMismatch] La notificación ya no pertenece a la '
              'conversación autorizada por la regla. No se envió nada.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
    }
    return null;
  } on Object catch (error) {
    return ToolOutcome(
      verdict: PolicyVerdict.denied,
      feedback:
          '[contextLockUnavailable] No se pudo revalidar la notificación: '
          '$error.',
      executionStatus: ToolExecutionStatus.notExecuted,
    );
  }
}
