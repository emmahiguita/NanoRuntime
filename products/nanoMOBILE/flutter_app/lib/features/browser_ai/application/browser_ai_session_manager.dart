import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser/application/browser_tab_notifier.dart';
import '../../browser/application/browser_webview_registry.dart';
import '../domain/browser_ai_provider.dart';
import '../domain/browser_ai_session.dart';
import '../infrastructure/browser_ai_session_prefs.dart';

/// QUÉ HACE:
/// Administra sesiones de chat AI: persiste el tabId en disco, reutiliza pestañas
/// existentes y guarda acciones pendientes para reintento post-login.
///
/// CÓMO FUNCIONA:
/// Al obtener un controlador: busca tab en memoria → en disco → crea nuevo.
/// Persiste el tabId vía [BrowserAiSessionPrefs] para sobrevivir reinicios.
///
/// POR QUÉ:
/// Sin persistencia del tabId, cada reinicio crea una nueva pestaña sin cookies
/// → el usuario debe loguearse de nuevo → "Acción requerida" siempre.
class BrowserAiSessionManager {
  final Ref _ref;

  // Sesiones en memoria (providerId → sesión activa)
  final Map<String, BrowserAiSession> _sessions = {};

  // Prompts pendientes por proveedor (para reintento post-login)
  final Map<String, String> _pendingPrompts = {};

  BrowserAiSessionManager(this._ref);

  /// Retorna el estado actual de la sesión para un proveedor.
  BrowserAiSession? getSession(String providerId) => _sessions[providerId];

  /// Guarda un prompt para reintento cuando el usuario complete el login.
  void setPendingPrompt(String providerId, String prompt) {
    _pendingPrompts[providerId] = prompt;
  }

  /// Recupera y elimina el prompt pendiente (consumir una sola vez).
  String? consumePendingPrompt(String providerId) {
    return _pendingPrompts.remove(providerId);
  }

  /// Obtiene o crea un controlador de WebView dedicado para el proveedor.
  /// Prioridad: memoria → disco → tab existente con URL → tab nuevo.
  Future<InAppWebViewController?> getOrCreateController(
    BrowserAiProvider provider,
  ) async {
    final tabNotifier = _ref.read(browserTabProvider.notifier);
    final tabState = _ref.read(browserTabProvider);
    final registry = _ref.read(browserWebViewRegistryProvider);

    // 1. Tab vivo en memoria
    final session = _sessions[provider.id];
    if (session?.tabId != null) {
      final ctrl = registry.controllerFor(session!.tabId!);
      if (ctrl != null) return ctrl;
    }

    // 2. TabId guardado en disco (sobrevive reinicios)
    final savedTabId = await BrowserAiSessionPrefs.loadTabId(provider.id);
    if (savedTabId != null) {
      final exists = tabState.tabs.any((t) => t.id == savedTabId);
      if (exists) {
        final ctrl = registry.controllerFor(savedTabId);
        if (ctrl != null) {
          _updateSession(provider.id, tabId: savedTabId);
          return ctrl;
        }
      }
      // El tab del disco ya no existe → borrar registro obsoleto
      await BrowserAiSessionPrefs.clearTabId(provider.id);
    }

    // 3. Tab abierto por el usuario con la URL del proveedor
    for (final tab in tabState.tabs) {
      final uri = Uri.tryParse(tab.url);
      if (uri != null && provider.canHandle(uri)) {
        final ctrl = registry.controllerFor(tab.id);
        if (ctrl != null) {
          _updateSession(provider.id, tabId: tab.id);
          await BrowserAiSessionPrefs.saveTabId(provider.id, tab.id);
          return ctrl;
        }
      }
    }

    // 4. Crear pestaña nueva dedicada (sin pisar la activa)
    final newTabId = tabNotifier.addTab(
      initialUrl: provider.defaultUrl.toString(),
    );
    _updateSession(provider.id, tabId: newTabId);
    await BrowserAiSessionPrefs.saveTabId(provider.id, newTabId);

    // Esperar a que el WebView registre su controlador (máx 3s)
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      final ctrl = registry.controllerFor(newTabId);
      if (ctrl != null) return ctrl;
    }

    return null;
  }

  /// Actualiza los metadatos de sesión de un proveedor.
  void _updateSession(
    String providerId, {
    String? tabId,
    bool? isLoggedIn,
    BrowserAiSessionStatus? status,
    String? lastResponse,
  }) {
    final current =
        _sessions[providerId] ??
        BrowserAiSession(
          providerId: providerId,
          lastActive: DateTime.now(),
        );
    _sessions[providerId] = current.copyWith(
      tabId: tabId,
      isLoggedIn: isLoggedIn,
      status: status,
      lastActive: DateTime.now(),
      lastResponse: lastResponse,
    );
  }

  /// Verifica el estado de autenticación de un proveedor.
  Future<bool> verifyLogin(BrowserAiProvider provider) async {
    final ctrl = await getOrCreateController(provider);
    if (ctrl == null) return false;
    final loggedIn = await provider.isLoggedIn(ctrl);
    _updateSession(provider.id, isLoggedIn: loggedIn);
    return loggedIn;
  }
}

/// Provider global de Riverpod para BrowserAiSessionManager.
final browserAiSessionManagerProvider = Provider<BrowserAiSessionManager>((ref) {
  return BrowserAiSessionManager(ref);
});
