import '../../platform/whatsapp_media_share.dart';
import '../tool_call.dart';
import 'whatsapp_contact_resolver.dart';
import 'whatsapp_command_input.dart';
import '../../../ledger/automation_activity_store.dart';
import '../agent_executor.dart';
import '../../voice/execution_cancellation.dart';
import 'whatsapp_open_verifier.dart';

/// Apertura real con identidad resuelta. El registro documenta agenda y canal;
/// no considera startActivity como mensaje enviado ni perfil verificado.
class WhatsAppChatOpener {
  const WhatsAppChatOpener(this.share, this.resolver);
  final WhatsAppMediaShare share;
  final WhatsAppContactResolver resolver;
  Future<String> open(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) async {
    if (cancellation?.isCancelled == true) {
      return '[cancelled] Apertura detenida.';
    }
    final rawContact = (call.args?['contact'] ?? '').toString().trim();
    final contactQ = rawContact.replaceFirst(
      RegExp(r'^(?:(?:este|el|al)\s+)?n[uú]mero\s+', caseSensitive: false),
      '',
    ).trim();
    final text = (call.args?['text'] ?? '').toString().trim();
    final pkg = call.args?['packageName'] as String?;
    final owner = call.args?['executionId'] as String?;
    void record(String route, String state, String detail, String target) {
      if (owner == null) return;
      AutomationActivityStore.instance.record(
        runId: owner,
        route: route,
        state: state,
        detail: detail,
        target: target,
        packageName: pkg ?? '',
      );
    }

    if (contactQ.isEmpty) {
      final ok = await share.openChat(
        contact: '',
        text: text,
        packageName: pkg,
        autoSend: false,
      );
      return ok
          ? '[completedUnverified] Android aceptó abrir WhatsApp; ventana final sin verificar.'
          : '[error] No se pudo abrir WhatsApp.';
    }

    final username = WhatsAppCommandInput.isUsername(contactQ);
    final resolved = username ? null : await resolver.resolve(contactQ);
    if (resolved == null && !username) {
      return '[error] Destinatario no encontrado o ambiguo. Usa el nombre exacto o su teléfono.';
    }
    if (resolved?.isGroup == true) {
      return '[error] Usa el flujo de grupos de WhatsApp para abrir este destinatario; no es un teléfono individual.';
    }
    record(
      'Agenda Android → identidad solicitada',
      'resolved',
      username
          ? 'Usuario explícito; la apertura no verifica su perfil.'
          : 'Destinatario resuelto sin elegir coincidencias ambiguas.',
      resolved?.name ?? contactQ,
    );
    final phone = resolved?.number ?? contactQ;
    final name = resolved?.name ?? contactQ;
    if (cancellation?.isCancelled == true) {
      return '[cancelled] Apertura detenida.';
    }

    // Esta herramienta solo navega. El envío vive en sendMessage y su policy.
    final ok = await share.openChat(
      contact: phone,
      text: text,
      packageName: pkg,
      autoSend: false,
    );
    record(
      'Canal Android → WhatsApp',
      ok ? 'launch_requested' : 'failed',
      ok
          ? 'Android aceptó la solicitud de apertura; no acredita un envío.'
          : 'El canal rechazó la apertura.',
      name,
    );
    if (!ok) return '[error] No se pudo abrir el chat con "$name".';
    final verification = await WhatsAppOpenVerifier(NanoAgentExecutor()).verify(
      phone,
      pkg ?? 'com.whatsapp',
      cancelled: () => cancellation?.isCancelled == true,
    );
    if (cancellation?.isCancelled == true) {
      return '[cancelled] Verificación detenida; revisa la pantalla actual.';
    }
    record(
      'Perfil → identidad → retorno',
      verification.verified ? 'verified' : 'unverified',
      verification.reason,
      name,
    );
    return '[${verification.verified ? 'completed' : 'completedUnverified'}] '
        'Chat "$name" ($phone): ${verification.reason}';
  }
}
