import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/platform/whatsapp_media_share.dart';
import '../engine/execution/handlers/whatsapp_command_input.dart';

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

  Future<void> configure() async {
    await const WhatsAppMediaShare().openAccessibilitySettings();
  }

  /// Abrir un chat no requiere pulsar controles externos. Escribir/enviar sí.
  static bool requiresAccessibility(String command) {
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
