import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registro central del estado nativo de cada pestaña del navegador.
///
/// - QUÉ HACE: Mantiene vivos los [InAppWebViewKeepAlive] y [InAppWebViewController]
///   para que el WebView no se destruya al cambiar de ruta o minimizar una pestaña.
/// - CÓMO FUNCIONA: Los keep-alive tokens son la identidad estable que permite mover
///   una superficie WebView entre rutas sin reinstanciar el widget nativo.
/// - POR QUÉ: Sin esto cada navegación al Home recrearía el WebView y cortaría el audio.
///   La pausa por vista preserva las otras pestañas y el audio activo.
class BrowserWebViewRegistry {
  final Map<String, InAppWebViewKeepAlive> _keepAlives = {};
  final Map<String, InAppWebViewController> _controllers = {};
  final Set<String> _initializedTabs = {};
  final Map<String, Object> _pauseRequests = {};

  /// Devuelve o crea el token keep-alive para una pestaña.
  InAppWebViewKeepAlive keepAliveFor(String tabId) =>
      _keepAlives.putIfAbsent(tabId, InAppWebViewKeepAlive.new);

  bool isInitialized(String tabId) => _initializedTabs.contains(tabId);

  InAppWebViewController? controllerFor(String tabId) => _controllers[tabId];

  /// Registra el controlador nativo al ser creado el WebView.
  void attachController(String tabId, InAppWebViewController controller) {
    _pauseRequests.remove(tabId);
    _initializedTabs.add(tabId);
    _controllers[tabId] = controller;
  }

  /// Pausa esta vista, nunca pauseTimers(): en Android detiene TODAS las vistas.
  /// Un token invalida consultas pendientes cuando la pestaña vuelve a abrirse.
  Future<void> pauseTab(String tabId) async {
    final ctrl = _controllers[tabId];
    if (ctrl == null) return;
    final request = Object();
    _pauseRequests[tabId] = request;
    try {
      // Revisar todos los reproductores, no solo el primero del documento.
      final raw = await ctrl.evaluateJavascript(
        source: '''(function(){
          return Array.from(document.querySelectorAll('video,audio'))
            .some(m => !m.paused && !m.ended);
        })();''',
      );
      if (raw == true ||
          _pauseRequests[tabId] != request ||
          !identical(_controllers[tabId], ctrl)) {
        return;
      }
      await ctrl.pause();
    } catch (_) {}
  }

  /// Invalida una pausa en curso y reanuda únicamente la vista restaurada.
  Future<void> resumeTab(String tabId) async {
    _pauseRequests.remove(tabId);
    try {
      await _controllers[tabId]?.resume();
    } catch (_) {}
  }

  /// Elimina la pestaña y libera su keep-alive nativo.
  Future<void> removeTab(String tabId) async {
    _pauseRequests.remove(tabId);
    _controllers.remove(tabId);
    _initializedTabs.remove(tabId);
    final keepAlive = _keepAlives.remove(tabId);
    if (keepAlive != null) {
      await InAppWebViewController.disposeKeepAlive(keepAlive);
    }
  }

  /// Limpia pestañas cuyo ID ya no existe en el state (evita leaks de memoria).
  void removeMissing(Set<String> liveTabIds) {
    final staleIds = _keepAlives.keys
        .where((id) => !liveTabIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      unawaited(removeTab(id));
    }
  }

  Future<void> dispose() async {
    for (final id in _keepAlives.keys.toList(growable: false)) {
      await removeTab(id);
    }
  }
}

final browserWebViewRegistryProvider = Provider<BrowserWebViewRegistry>((ref) {
  final registry = BrowserWebViewRegistry();
  ref.onDispose(() => unawaited(registry.dispose()));
  return registry;
});
