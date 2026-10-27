part of 'agent_tool_dispatcher.dart';

/// Ayudas del dispositivo: comprueba identidad de app y contexto de notificación.
extension _AgentDeviceHelpers on AgentToolDispatcher {
  /// Valida el paquete antes de abrir; una modalidad explícita no se descarta
  /// ni se presenta como flotante si Android solo acepta la solicitud.
  Future<String> _handleLaunchApp(ToolCall call) async {
    var packageName = call.packageNameArg?.trim() ?? '';
    if (packageName.isEmpty) {
      return '[tool] launch_app requiere args {packageName}.';
    }
    if (_installedAppCatalog != null) {
      final match = await _installedAppCatalog.findApp(packageName);
      if (match is AppMatchResolved) {
        packageName = match.app.packageName;
      } else if (match is AppMatchAmbiguous) {
        final candidates = match.candidates
            .take(3)
            .map((c) => '${c.label} (${c.packageName})')
            .join(', ');
        return '[ambiguousApp] Múltiples aplicaciones coinciden con "$packageName": $candidates.';
      }
    }
    final windowMode = call.args?['windowMode'];
    if (windowMode != null && windowMode != 'floating') {
      return '[unsupported] Modalidad de ventana no reconocida.';
    }
    if (windowMode == 'floating') {
      return WhatsAppWindowLauncher.open(packageName);
    }
    final launched = await _launchPackage(packageName);
    if (!launched) {
      return '[launchFailed] Android no pudo abrir el paquete "$packageName".';
    }
    final expectation = _uiHandler
        .expectationFor(call)
        .copyWith(expectedPackage: packageName);
    return _uiHandler.verifiedFeedback(
      'Aplicación abierta por Intent: $packageName.',
      expectation,
    );
  }

  Future<String> _handleReplyNotification(ToolCall call) async {
    final key = call.keyArg?.trim() ?? '';
    final text = call.textArg?.trim() ?? '';
    if (key.isEmpty) return '[tool] reply_notification requiere "key".';
    if (text.isEmpty) return '[tool] reply_notification requiere "text".';
    final rawActionIndex = call.args?['actionIndex'];
    final rawPostTime = call.args?['postTime'];
    return _notificationHandler.replyNotification(
      key: key,
      text: text,
      actionIndex: rawActionIndex is num ? rawActionIndex.toInt() : null,
      remoteInputKey: (call.args?['remoteInputKey'] as String?)?.trim(),
      contextFingerprint: (call.args?['contextFingerprint'] as String?)?.trim(),
      postTime: rawPostTime is num ? rawPostTime.toInt() : null,
    );
  }
}
