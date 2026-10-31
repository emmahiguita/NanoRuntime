import '../../perception/nano_snapshot.dart';
import '../tool_call.dart';
import '../tool_outcome.dart';
import '../tool_registry.dart';
import 'whatsapp_reply_context.dart';

/// Valida el objetivo observado antes de reclamar el envío irreversible.
/// Solo admite replyInPlace con evidencia completa, nunca un bool de autorización.
ToolOutcome? validateWhatsAppReplyContext(
  ToolCall call,
  NanoSnapshot? snapshot,
) {
  final args = call.args ?? const <String, dynamic>{};
  final pkg = args['packageName']?.toString() ?? '';
  final window = args['windowId'];
  final valid =
      call.tool == 'whatsapp.send_message' &&
      args['replyInPlace'] == true &&
      const {'com.whatsapp', 'com.whatsapp.w4b'}.contains(pkg) &&
      window is int &&
      WhatsAppReplyContext.matches(
        snapshot,
        packageName: pkg,
        target: args['contact']?.toString() ?? '',
        windowId: window,
        root: args['rootIdentity']?.toString() ?? '',
        contextFingerprint: args['contextFingerprint']?.toString() ?? '',
      );
  if (valid) return null;
  return const ToolOutcome(
    verdict: PolicyVerdict.denied,
    feedback:
        '[contextChanged] El chat observado cambió o falta su identidad; no se escribió ni envió.',
    executionStatus: ToolExecutionStatus.notExecuted,
  );
}
