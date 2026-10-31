import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/platform/whatsapp_media_share.dart';
import '../engine/execution/handlers/whatsapp_command_input.dart';
import '../engine/planning/whatsapp_component_requests.dart';

/// Estado observado del servicio de Nano. Consulta al entrar, al volver de
/// Ajustes y antes de un envío; no crea sondeos permanentes ni concede permisos.
class AutomationAccessController extends ChangeNotifier
    with WidgetsBindingObserver {
  AutomationAccessController() {
    WidgetsBinding.instance.addObserver(this);
  }
  bool? ready;
  bool _disposed = false;
  Future<bool>? _check;
  Timer? _settingsWatch;

  Future<bool> refresh() =>
      _check ??= _refresh().whenComplete(() => _check = null);
  Future<bool> _refresh() async {
    bool? observed;
    try {
      observed = await const WhatsAppMediaShare()
          .isAccessibilityEnabled()
          .timeout(const Duration(seconds: 3));
    } on Object {
      observed = null;
    }
    if (!_disposed && ready != observed) {
      ready = observed;
      notifyListeners();
    }
    return observed == true;
  }

  /// Al abrir Ajustes, espera brevemente la conexión real del servicio: el
  /// panel flotante puede no recibir un evento de regreso de la actividad.
  /// La observación termina al conectar, al agotarse el plazo o al cerrar.
  Future<void> configure() async {
    _settingsWatch?.cancel();
    await const WhatsAppMediaShare().openAccessibilitySettings();
    if (_disposed) return;
    var remaining = 60;
    _settingsWatch = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_disposed || --remaining <= 0) {
        timer.cancel();
        return;
      }
      if (await refresh()) timer.cancel();
    });
    unawaited(refresh().then((connected) {
      if (connected) _settingsWatch?.cancel();
    }));
  }

  /// Las respuestas en el chat visible también requieren el servicio conectado.
  /// Abrir un chat sin escribir mantiene la ruta existente.
  static bool requiresAccessibility(String command) {
    try {
      if (WhatsAppComponentRequests.currentReply(command) != null ||
          WhatsAppComponentRequests.currentChatDraft(command) != null) {
        return true;
      }
    } on FormatException {
      // Es una respuesta incompleta: esta consulta de permisos no ejecuta ni
      // valida mensajes. El preparador publicará la aclaración en modo Auto.
      return true;
    }
    final match = RegExp(
      r'^@(whatsapp|wpp)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(command.trim());
    if (match == null || match[2] == '--estado') return false;
    return WhatsAppCommandInput.parse(match[2]!)?.message.isNotEmpty ?? false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _settingsWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
