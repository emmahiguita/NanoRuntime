import '../../../../../core/services/nano_runtime_api.dart';
import '../../../../../core/services/native_ui_context.dart';
import '../agent_executor.dart';
import '../../perception/nano_selector.dart';
import '../../perception/nano_snapshot.dart';

/// Verifica la identidad pública del perfil después de abrir el chat. No usa
/// mensajes como prueba del destinatario y nunca pulsa Enviar ni repite el tap.
final class WhatsAppOpenVerifier {
  const WhatsAppOpenVerifier(this.executor);
  final AgentExecutor executor;

  /// Observa cambios durante un plazo acotado; el sondeo no ejecuta acciones.
  Future<NanoSnapshot?> _wait(
    String pkg,
    bool Function(NanoSnapshot) ready, [
    bool Function()? cancelled,
  ]) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (cancelled?.call() == true) return null;
      final snap = await executor.snapshot();
      if (snap != null && !snap.truncated && snap.package == pkg && ready(snap)) {
        return snap;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return null;
  }

  /// Abrir el perfil y volver son navegación, no entrega ni autenticación de
  /// cuenta. Si WhatsApp no expone sus datos, el resultado sigue sin verificar.
  Future<({bool verified, String reason})> verify(
    String target,
    String pkg, {
    bool Function()? cancelled,
  }) async {
    List<NanoNode> headers(NanoSnapshot s) => s.visibleNodes
        .where(
          (n) =>
              n.packageName == pkg &&
              n.id == '$pkg:id/conversation_contact_name' &&
              n.text.isNotEmpty,
        )
        .toList();
    final chat = await _wait(
      pkg,
      (s) =>
          headers(s).length == 1 &&
          s.visibleNodes.any((n) => n.id == '$pkg:id/entry' && n.editable),
      cancelled,
    );
    if (chat == null) {
      return (
        verified: false,
        reason: 'No se observó una conversación identificable.',
      );
    }
    final header = headers(chat).single;
    if (header.rootIdentity.isEmpty) {
      return (
        verified: false,
        reason: 'La ventana no ofrece identidad suficiente.',
      );
    }
    final guard = {
      'package': pkg,
      'windowId': header.windowId,
      'rootIdentity': header.rootIdentity,
      'headerId': header.id,
      'headerText': header.text,
    };
    if (cancelled?.call() == true) {
      return (verified: false, reason: 'Verificación cancelada.');
    }
    final clicked = await NativeUiContext.run(
      guard,
      () => executor.tap(
        NanoSelector(
          packageName: pkg,
          resourceId: header.id,
          text: header.text,
        ),
      ),
    );
    if (!clicked.ok) {
      return (
        verified: false,
        reason: 'No se abrió el perfil con certeza; no se repitió el clic.',
      );
    }
    bool isProfile(NanoSnapshot s) =>
        s.visibleNodes
                .where(
                  (n) =>
                      n.packageName == pkg && n.id == '$pkg:id/contact_title',
                )
                .length ==
            1 &&
        !s.visibleNodes.any((n) => n.id == '$pkg:id/entry' && n.editable);
    final profile = await _wait(pkg, isProfile, cancelled);
    if (profile == null) {
      return (
        verified: false,
        reason: 'El perfil no expuso una identidad verificable.',
      );
    }
    final username = target.startsWith('@');
    final digits = target.replaceAll(RegExp(r'\D'), '');
    final matches = profile.visibleNodes.where((node) {
      if (node.packageName != pkg || node.password) return false;
      final text = node.text.trim();
      if (username) {
        return node.id == '$pkg:id/contact_subtitle' &&
            text.replaceFirst(RegExp(r'^@'), '').toLowerCase() ==
                target.substring(1).toLowerCase();
      }
      return digits.length >= 7 &&
          RegExp(r'^\+?[\d\s()\-]+$').hasMatch(text) &&
          text.replaceAll(RegExp(r'\D'), '') == digits;
    }).toList();
    // Revalida el perfil antes de Atrás; no navega a ciegas si el usuario salió.
    final current = await executor.snapshot();
    final profileTitle = profile.visibleNodes.singleWhere(
      (n) => n.id == '$pkg:id/contact_title',
    );
    if (current == null ||
        current.truncated ||
        current.package != pkg ||
        !isProfile(current) ||
        !current.visibleNodes.any(
          (n) =>
              n.id == profileTitle.id &&
              n.text == profileTitle.text &&
              n.windowId == profileTitle.windowId &&
              n.rootIdentity == profileTitle.rootIdentity,
        )) {
      return (
        verified: false,
        reason: 'La pantalla cambió durante la verificación.',
      );
    }
    if (cancelled?.call() == true) {
      return (
        verified: false,
        reason: 'Verificación cancelada; no se pulsó Atrás.',
      );
    }
    final back = await NanoRuntimeApi.instance.agentGlobalAction('back');
    if (!back) {
      return (
        verified: false,
        reason: 'No se confirmó el retorno del perfil al chat.',
      );
    }
    final restored = await _wait(
      pkg,
      (s) =>
          headers(s).length == 1 &&
          headers(s).single.text == header.text &&
          s.visibleNodes.any((n) => n.id == '$pkg:id/entry'),
      cancelled,
    );
    return (
      verified: matches.length == 1 && restored != null,
      reason: matches.length != 1
          ? 'El perfil no confirmó exactamente el teléfono o usuario solicitado.'
          : restored == null
          ? 'Identidad observada; retorno al chat no confirmado.'
          : 'Identidad del perfil y regreso al chat observados; no se envió ningún mensaje.',
    );
  }
}
