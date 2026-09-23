import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_dialog_guard.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_webview_load_synchronizer.dart';

/// Manejador de ciclo de vida, eventos de seguridad y puentes JS de `InAppWebView`.
///
/// - ¿Qué hace?: Centraliza verificación de firewall (SSRF), respuestas HTTP Auth/SSL,
///   solicitudes de permisos Web, inyección post-carga de scripts y sync con Riverpod.
/// - ¿Cómo?: Recibe eventos nativos del WebView y los delega en notifiers y diálogos.
/// - ¿Por qué?: SRP y DIP de SOLID; [isAlive] previene el bug "ref after disposed"
///   cuando el WebView dispara callbacks después de destruir el widget padre.
class BrowserWebViewLifecycleHandler {
  final BuildContext Function() getContext;
  final WidgetRef ref;
  BrowserTabModel tab;
  String? reportedUrl;
  int _loadGeneration = 0;
  bool isDesktopMode, isDarkModeWeb;
  double currentZoom;
  final void Function(double scale) onZoomChanged;
  final void Function(String domain, String username, String password)
  onPromptSaveCredential;
  final ValueChanged<InAppWebViewController>? onControllerCreated;
  final void Function(String url)? onExternalPrompt;

  /// Retorna true si el widget padre sigue montado. Previene ref-after-disposed.
  final bool Function() isAlive;
  late final BrowserWebViewDialogGuard _dialogs;

  BrowserWebViewLifecycleHandler({
    required this.getContext,
    required this.ref,
    required this.tab,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.onPromptSaveCredential,
    required this.isAlive,
    this.onControllerCreated,
    this.onExternalPrompt,
  }) {
    _dialogs = BrowserWebViewDialogGuard(
      context: getContext,
      ref: ref,
      isAlive: isAlive,
    );
  }

  void onWebViewCreated(InAppWebViewController ctrl) {
    if (!isAlive()) return;
    ref.read(browserWebViewRegistryProvider).attachController(tab.id, ctrl);
    onControllerCreated?.call(ctrl);
    ctrl.addJavaScriptHandler(
      handlerName: 'nanoZoomUpdate',
      callback: (args) {
        // El WebView puede emitir eventos después de que su tarjeta desaparece.
        // Se ignoran para no actualizar estado ni widgets ya desmontados.
        if (!isAlive()) return null;
        if (args.isNotEmpty && args[0] is num) {
          final value = (args[0] as num).toDouble();
          if (!value.isFinite) return null;
          final z = value.clamp(0.1, 3.0);
          onZoomChanged(z);
          ref
              .read(browserTabProvider.notifier)
              .updateTabById(tab.id, zoomLevel: z);
        }
      },
    );
    ctrl.addJavaScriptHandler(
      handlerName: 'nanoSaveCredential',
      callback: (args) {
        // Misma protección para evitar banners sobre un contexto inválido.
        if (!isAlive()) return null;
        if (args.length >= 3 && (args[2]?.toString().isNotEmpty ?? false)) {
          onPromptSaveCredential(
            args[0]?.toString() ?? '',
            args[1]?.toString() ?? '',
            args[2]!.toString(),
          );
        }
      },
    );
  }

  void onLoadStart(InAppWebViewController ctrl, WebUri? url) {
    if (url == null) return;
    // Nunca se presenta UI desde un callback cuyo widget ya fue destruido.
    if (!isAlive()) return;
    ++_loadGeneration;
    final urlStr = reportedUrl = url.toString();
    if (!BrowserSecurityFirewall.isAllowedUrl(urlStr)) {
      ctrl.stopLoading();
      _dialogs.showBlocked(
        url: urlStr,
        reason: 'Dirección o protocolo bloqueado por Firewall de Seguridad.',
      );
      return;
    }
    ref
        .read(browserTabProvider.notifier)
        .updateTabById(tab.id, url: urlStr, isLoading: true, progress: 0.1);
  }

  Future<void> onLoadStop(InAppWebViewController ctrl, WebUri? url) async {
    final generation = _loadGeneration;
    await BrowserWebViewLoadSynchronizer(
      ref: ref, tab: tab, isDesktopMode: isDesktopMode,
      isDarkModeWeb: isDarkModeWeb, currentZoom: currentZoom,
      isAlive: () => isAlive() && generation == _loadGeneration,
    ).synchronize(ctrl, url);
  }

  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
    InAppWebViewController ctrl,
    NavigationAction act,
  ) async {
    if (!isAlive()) return NavigationActionPolicy.CANCEL;
    final uri = act.request.url?.uriValue;
    if (uri == null) return NavigationActionPolicy.CANCEL;
    final u = uri.toString();
    if (BrowserSecurityFirewall.isExternalScheme(u)) {
      onExternalPrompt?.call(u);
      return NavigationActionPolicy.CANCEL;
    }
    if (!BrowserSecurityFirewall.isAllowedUrl(u)) {
      _dialogs.showBlocked(
        url: u,
        reason:
            'Dirección privada, puerto interno o protocolo no seguro bloqueado.',
      );
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<ServerTrustAuthResponse?> onReceivedServerTrustAuthRequest(
    InAppWebViewController ctrl,
    URLAuthenticationChallenge ch,
  ) async {
    return _dialogs.requestServerTrust(ch);
  }

  Future<HttpAuthResponse?> onReceivedHttpAuthRequest(
    InAppWebViewController ctrl,
    URLAuthenticationChallenge ch,
  ) async {
    return _dialogs.requestHttpAuth(ch);
  }

  Future<PermissionResponse> onPermissionRequest(
    InAppWebViewController ctrl,
    PermissionRequest r,
  ) async {
    return _dialogs.requestPermission(r);
  }
}
