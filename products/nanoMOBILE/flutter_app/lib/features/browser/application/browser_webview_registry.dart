import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the native identity of every browser tab independently from the UI.
///
/// A browser surface may move from the Home card to the fullscreen route, but
/// its native WebView must not be recreated. The plugin keep-alive token is the
/// stable identity that makes that handoff possible.
class BrowserWebViewRegistry {
  final Map<String, InAppWebViewKeepAlive> _keepAlives = {};
  final Map<String, InAppWebViewController> _controllers = {};
  final Set<String> _initializedTabs = {};

  InAppWebViewKeepAlive keepAliveFor(String tabId) {
    return _keepAlives.putIfAbsent(tabId, InAppWebViewKeepAlive.new);
  }

  bool isInitialized(String tabId) => _initializedTabs.contains(tabId);

  InAppWebViewController? controllerFor(String tabId) => _controllers[tabId];

  void attachController(String tabId, InAppWebViewController controller) {
    _initializedTabs.add(tabId);
    _controllers[tabId] = controller;
  }

  /// Pausa los temporizadores de JS de una pestaña (previene procesos zombis de CPU).
  Future<void> pauseTab(String tabId) async {
    try {
      await _controllers[tabId]?.pauseTimers();
    } catch (_) {}
  }

  /// Reanuda los temporizadores de JS al restaurar o maximizar una pestaña.
  Future<void> resumeTab(String tabId) async {
    try {
      await _controllers[tabId]?.resumeTimers();
    } catch (_) {}
  }

  Future<void> removeTab(String tabId) async {
    _controllers.remove(tabId);
    _initializedTabs.remove(tabId);
    final keepAlive = _keepAlives.remove(tabId);
    if (keepAlive != null) {
      await InAppWebViewController.disposeKeepAlive(keepAlive);
    }
  }

  void removeMissing(Set<String> liveTabIds) {
    final staleIds = _keepAlives.keys
        .where((tabId) => !liveTabIds.contains(tabId))
        .toList(growable: false);
    for (final tabId in staleIds) {
      unawaited(removeTab(tabId));
    }
  }

  Future<void> dispose() async {
    final tabIds = _keepAlives.keys.toList(growable: false);
    for (final tabId in tabIds) {
      await removeTab(tabId);
    }
  }
}

final browserWebViewRegistryProvider = Provider<BrowserWebViewRegistry>((ref) {
  final registry = BrowserWebViewRegistry();
  ref.onDispose(() => unawaited(registry.dispose()));
  return registry;
});
