import '../domain/automation_goal.dart';
import '../engine/execution/agent_executor.dart';
import 'automation_artifact_commands.dart';
import '../engine/execution/tool_call.dart';
import '../engine/execution/handlers/whatsapp_reply_context.dart';
import '../domain/prepared_automation_goal.dart';
import '../engine/planning/whatsapp_component_requests.dart';

/// Prepara acciones WhatsApp a partir de peticiones explícitas y, para «este
/// chat», de una cabecera accesible observada. No usa texto de burbujas como identidad.
final class WhatsAppUiGoalPreparer {
  const WhatsAppUiGoalPreparer(this.executor);
  final AgentExecutor Function() executor;

  /// Una respuesta conserva paquete (personal/Business), destinatario y texto.
  /// El envío se liga a la ventana observada; no consulta agenda ni reabre
  /// otro chat por un título que podría pertenecer a un grupo homónimo.
  Future<PreparedAutomationGoal> prepare(
    String input, {
    bool Function()? isCurrent,
  }) async {
    final text = WhatsAppComponentRequests.normalize(input);
    final artifact = await NanoArtifactCommands.prepare(
      text,
      isCancelled: () => isCurrent?.call() == false,
    );
    if (artifact != null) {
      return PreparedAutomationGoal(
        AutomationGoal(text: text),
        plan: [
          ToolCall(
            tool: 'whatsapp.share_file',
            args: {
              'contact': artifact.contact,
              'path': artifact.file.path,
              'packageName': 'com.whatsapp',
            },
          ),
        ],
      );
    }
    if (WhatsAppComponentRequests.isFloating(text)) {
      final business = text.toLowerCase().contains('business');
      return PreparedAutomationGoal(
        AutomationGoal(text: text),
        plan: [
          ToolCall(
            tool: 'launch_app',
            args: {
              'packageName': business ? 'com.whatsapp.w4b' : 'com.whatsapp',
              'windowMode': 'floating',
            },
          ),
        ],
      );
    }
    final reply = WhatsAppComponentRequests.currentReply(text);
    if (reply == null) {
      return PreparedAutomationGoal(AutomationGoal(text: text));
    }
    final snap = await executor().snapshot();
    if (snap == null ||
        !const {'com.whatsapp', 'com.whatsapp.w4b'}.contains(snap.package)) {
      throw const FormatException(
        'Para «este chat», abre WhatsApp y usa el búho sobre la conversación. Desde Nano indica nombre, número o @usuario.',
      );
    }
    if (snap.truncated) {
      throw const FormatException(
        'La lectura del chat es parcial; indica el destinatario exacto.',
      );
    }
    final pkg = snap.package;
    final headers = snap.nodes
        .where(
          (n) =>
              n.visible &&
              n.packageName == pkg &&
              n.id == '$pkg:id/conversation_contact_name' &&
              n.text.trim().isNotEmpty,
        )
        .toList();
    final editors = snap.nodes
        .where(
          (n) =>
              n.visible &&
              n.enabled &&
              n.packageName == pkg &&
              n.id == '$pkg:id/entry' &&
              n.editable &&
              !n.password,
        )
        .toList();
    if (headers.length != 1 ||
        editors.length != 1 ||
        headers.single.windowId != editors.single.windowId) {
      throw const FormatException(
        'No hay una cabecera y un editor identificables con certeza. Indica el destinatario.',
      );
    }
    if (headers.single.rootIdentity.isEmpty ||
        headers.single.rootIdentity != editors.single.rootIdentity) {
      throw const FormatException(
        'No hay identidad de ventana suficiente para responder aquí.',
      );
    }
    if (editors.single.text.trim().isNotEmpty) {
      throw const FormatException(
        'Ya hay un borrador en WhatsApp. Revísalo antes de sustituirlo.',
      );
    }
    final fingerprint = WhatsAppReplyContext.fingerprint(
      snap,
      headers.single.windowId,
      headers.single.rootIdentity,
    );
    if (fingerprint == null) {
      throw const FormatException(
        'No hay contexto visible suficiente para responder aquí.',
      );
    }
    final target = headers.single.text.trim();
    return PreparedAutomationGoal(
      AutomationGoal(text: 'WhatsApp $pkg · $target\nRespuesta: $reply'),
      plan: [
        ToolCall(
          tool: 'whatsapp.send_message',
          args: {
            'contact': target,
            'text': reply,
            'packageName': pkg,
            'replyInPlace': true,
            'windowId': headers.single.windowId,
            'rootIdentity': headers.single.rootIdentity,
            'contextFingerprint': fingerprint,
          },
        ),
      ],
    );
  }
}
