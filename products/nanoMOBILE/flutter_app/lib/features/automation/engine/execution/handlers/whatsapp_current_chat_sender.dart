import '../../../../../core/services/nano_runtime_api.dart';
import '../../orchestration/commit_guard.dart';
import '../../perception/nano_selector.dart';
import '../../perception/nano_snapshot.dart';
import '../../perception/semantic/screen_graph.dart';
import '../../voice/execution_cancellation.dart';
import '../agent_executor.dart';
import '../tool_call.dart';
import 'whatsapp_reply_context.dart';

/// Responde en la ventana observada sin agenda, deep link ni resolver un título
/// como otra persona. Reutiliza ejecutor y CommitGuard; el tap no se reintenta.
final class WhatsAppCurrentChatSender {
  WhatsAppCurrentChatSender({AgentExecutor? executor, NanoRuntimeApi? api})
    : _executor = executor ?? NanoAgentExecutor(),
      _api = api ?? NanoRuntimeApi.instance;
  final AgentExecutor _executor;
  final NanoRuntimeApi _api;

  /// Exige la cabecera/ventana original y un editor vacío antes de escribir.
  /// Tras escribir revalida texto exacto, contexto y botón de envío real.
  Future<String> send(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) async {
    final pkg = call.args?['packageName']?.toString() ?? '';
    final target = call.args?['contact']?.toString() ?? '';
    final text = call.args?['text']?.toString() ?? '';
    final root = call.args?['rootIdentity']?.toString() ?? '';
    final window = call.args?['windowId'];
    final fingerprint = call.args?['contextFingerprint']?.toString() ?? '';
    var didDispatch = false;
    if (!const {'com.whatsapp', 'com.whatsapp.w4b'}.contains(pkg) ||
        target.isEmpty ||
        text.isEmpty ||
        root.isEmpty ||
        fingerprint.isEmpty ||
        window is! int) {
      return '[error] Falta evidencia del chat actual; no se escribió ni envió.';
    }
    bool matches(NanoSnapshot? snapshot) {
      if (snapshot == null || snapshot.truncated || snapshot.package != pkg) {
        return false;
      }
      final active = snapshot.windows.any(
        (w) =>
            w.windowId == window &&
            w.windowType == 1 &&
            w.packageName == pkg &&
            (w.active || w.focused),
      );
      if (!active) return false;
      final headers = snapshot.nodes.where(
        (n) =>
            n.visible &&
            n.packageName == pkg &&
            n.id == '$pkg:id/conversation_contact_name',
      );
      return headers.length == 1 &&
          headers.single.text.trim() == target &&
          headers.single.windowId == window &&
          WhatsAppReplyContext.rootKey(headers.single.rootIdentity) ==
              WhatsAppReplyContext.rootKey(root) &&
          (didDispatch ||
              WhatsAppReplyContext.fingerprint(snapshot, window, root) ==
                  fingerprint);
    }

    Future<ScreenGraph?> observe() async {
      final snapshot = await _executor.snapshot();
      return matches(snapshot) ? ScreenGraph.fromSnapshot(snapshot!) : null;
    }

    bool cancelled() => cancellation?.isCancelled ?? false;
    if (cancelled()) return '[cancelled] Respuesta detenida antes de escribir.';
    final before = await _executor.snapshot();
    if (!matches(before)) {
      return '[error] La conversación cambió; no se respondió.';
    }
    final editors = before!.nodes
        .where(
          (n) =>
              n.visible &&
              n.enabled &&
              n.id == '$pkg:id/entry' &&
              n.packageName == pkg &&
              n.windowId == window &&
              WhatsAppReplyContext.rootKey(n.rootIdentity) ==
                  WhatsAppReplyContext.rootKey(root) &&
              n.editable &&
              !n.password,
        )
        .toList();
    if (editors.length != 1 || editors.single.text.isNotEmpty) {
      return '[clarification] El editor cambió o ya contiene un borrador. Revísalo.';
    }
    if (cancelled()) return '[cancelled] Respuesta detenida antes de escribir.';
    final written = await _executor.setText(
      NanoSelector(packageName: pkg, resourceId: '$pkg:id/entry'),
      text,
    );
    if (!written.ok) {
      return '[error] No se pudo preparar el texto; no se pulsó Enviar.';
    }
    if (cancelled()) {
      return '[cancelled] Se detuvo antes de enviar; queda un borrador en WhatsApp.';
    }
    final guard = CommitGuard(observe: observe);
    final captured = await guard.capture(conversation: target, draft: text);
    if (!captured.ready) return '[error] No se enviará: ${captured.reason}';
    final context = captured.context!;
    final checked = await guard.revalidate(context);
    if (!checked.ready) return '[error] No se enviará: ${checked.reason}';
    final last = await _executor.snapshot();
    final exact = last?.nodes
        .where(
          (n) =>
              n.visible &&
              n.id == '$pkg:id/entry' &&
              n.windowId == window &&
              WhatsAppReplyContext.rootKey(n.rootIdentity) ==
                  WhatsAppReplyContext.rootKey(root),
        )
        .toList();
    if (!matches(last) || exact?.length != 1 || exact!.single.text != text) {
      return '[error] El borrador o la ventana cambió antes del envío.';
    }
    if (cancelled()) return '[cancelled] Se detuvo antes de pulsar Enviar.';
    didDispatch = true;
    final dispatched = await _executor.tap(
      NanoSelector.parse(context.sendSelector),
    );
    if (!dispatched.ok) {
      return '[timeoutOutcomeUnknown] No se acreditó el clic. No repitas sin revisar WhatsApp.';
    }
    // Desde el tap no se cancela la observación ni se repite: reconciliar
    // permite informar si quedó eco local, sin afirmar recepción remota.
    final evidence = await guard.verifyAfterDispatch(context);
    if (evidence.status != SendEvidenceStatus.localSendVerified) {
      return '[timeoutOutcomeUnknown] Envío no acreditado completamente: ${evidence.reason}. No se reintentó.';
    }
    if (cancelled()) {
      return '[completedUnverified] Eco local observado; detención solicitada. Entrega no confirmada.';
    }
    final returned = await _returnToNano();
    return '[completedUnverified] Respuesta en el chat visible y eco local observados. '
        '${returned ? 'Regreso a Nano verificado.' : 'No se verificó el regreso a Nano.'} '
        'Entrega y lectura no confirmadas.';
  }

  /// Regresa una sola vez y observa el paquete real. No usa Atrás para salir
  /// del chat ni considera la burbuja como prueba de que Nano esté en primer plano.
  Future<bool> _returnToNano() async {
    if (!await _api.agentLaunchPackage('dev.nanoai.mobile')) return false;
    for (var attempt = 0; attempt < 5; attempt++) {
      final snapshot = await _executor.snapshot();
      if (snapshot?.windows.any(
            (w) =>
                w.windowType == 1 &&
                w.focused &&
                w.packageName == 'dev.nanoai.mobile',
          ) ==
          true) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }
}
