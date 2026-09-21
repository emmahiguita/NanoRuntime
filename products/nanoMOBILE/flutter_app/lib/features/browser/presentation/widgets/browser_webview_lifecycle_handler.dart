import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_credential_notifier.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/application/browser_webview_registry.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';

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
  final BrowserTabModel tab;
  final bool isDesktopMode, isDarkModeWeb;
  final double currentZoom;
  final void Function(double scale) onZoomChanged;
  final void Function(String domain, String username, String password) onPromptSaveCredential;
  final ValueChanged<InAppWebViewController>? onControllerCreated;
  final void Function(String url)? onExternalPrompt;
  /// Retorna true si el widget padre sigue montado. Previene ref-after-disposed.
  final bool Function() isAlive;

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
  });

  void onWebViewCreated(InAppWebViewController ctrl) {
    ref.read(browserWebViewRegistryProvider).attachController(tab.id, ctrl);
    onControllerCreated?.call(ctrl);
    ctrl.addJavaScriptHandler(handlerName: 'nanoZoomUpdate', callback: (args) {
      if (args.isNotEmpty && args[0] is num) {
        final z = (args[0] as num).toDouble();
        onZoomChanged(z);
        ref.read(browserTabProvider.notifier).updateTabById(tab.id, zoomLevel: z);
      }
    });
    ctrl.addJavaScriptHandler(handlerName: 'nanoSaveCredential', callback: (args) {
      if (args.length >= 3 && (args[2]?.toString().isNotEmpty ?? false)) {
        onPromptSaveCredential(args[0]?.toString() ?? '', args[1]?.toString() ?? '', args[2]!.toString());
      }
    });
  }

  void onLoadStart(InAppWebViewController ctrl, WebUri? url) {
    if (url == null) return;
    final urlStr = url.toString();
    if (!BrowserSecurityFirewall.isAllowedUrl(urlStr)) {
      ctrl.stopLoading();
      BrowserDialogHelper.showFirewallBlockedDialog(
        context: getContext(), url: urlStr, reason: 'Dirección o protocolo bloqueado por Firewall de Seguridad.',
      );
      return;
    }
    // Guard: widget puede haberse destruido antes de este callback.
    if (!isAlive()) return;
    ref.read(browserTabProvider.notifier).updateTabById(tab.id, url: urlStr, isLoading: true, progress: 0.1);
  }

  Future<void> onLoadStop(InAppWebViewController ctrl, WebUri? url) async {
    final title = await ctrl.getTitle(), canBack = await ctrl.canGoBack(), canFwd = await ctrl.canGoForward();
    // Guard tras awaits: el widget pudo destruirse mientras se esperaba.
    if (!isAlive()) return;
    if (url != null) {
      final rUrl = url.toString();
      ref.read(browserTabProvider.notifier).updateTabById(
        tab.id, url: rUrl, title: title?.isNotEmpty == true ? title : null,
        isLoading: false, progress: 1.0, canGoBack: canBack, canGoForward: canFwd,
      );
      ref.read(browserHistoryProvider.notifier).recordVisit(rUrl, title ?? '');
      if (url.uriValue.host.isNotEmpty) {
        final creds = await ref.read(browserCredentialProvider.notifier).getCredentialsForDomain(url.uriValue.host);
        if (!isAlive()) return;
        if (creds.isNotEmpty) {
          await ctrl.evaluateJavascript(source: BrowserScripts.buildAutofillScript(creds.first.username, creds.first.password));
        }
      }
    }
    try {
      if (url != null && (url.uriValue.host.contains('youtube.com') || url.uriValue.host.contains('youtu.be'))) {
        await ctrl.evaluateJavascript(
          source: "document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);",
        );
      }
      await ctrl.evaluateJavascript(source: isDesktopMode ? BrowserScripts.desktopViewportAdapterScript : BrowserScripts.mobileViewportAdapterScript);
      await ctrl.evaluateJavascript(source: BrowserScripts.pinchZoomEngineScript);
      final ez = tab.zoomLevel != 1.0 ? tab.zoomLevel : currentZoom;
      if (ez != 1.0) await ctrl.evaluateJavascript(source: BrowserScripts.setZoomLevelScript(ez));
      if (isDarkModeWeb) await ctrl.evaluateJavascript(source: BrowserScripts.toggleDarkModeWebScript);
    } catch (_) {}
    // Guard final antes de usar ref.
    if (!isAlive()) return;
    ref.read(browserPipProvider.notifier).attachController(ctrl);
  }


  Future<NavigationActionPolicy> shouldOverrideUrlLoading(InAppWebViewController ctrl, NavigationAction act) async {
    final uri = act.request.url?.uriValue;
    if (uri == null) return NavigationActionPolicy.CANCEL;
    final u = uri.toString();
    if (BrowserSecurityFirewall.isExternalScheme(u)) {
      onExternalPrompt?.call(u);
      return NavigationActionPolicy.CANCEL;
    }
    if (!BrowserSecurityFirewall.isAllowedUrl(u)) {
      BrowserDialogHelper.showFirewallBlockedDialog(
        context: getContext(), url: u, reason: 'Dirección privada, puerto interno o protocolo no seguro bloqueado.',
      );
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<ServerTrustAuthResponse?> onReceivedServerTrustAuthRequest(InAppWebViewController ctrl, URLAuthenticationChallenge ch) async {
    final resp = await BrowserDialogHelper.showSslWarningDialog(context: getContext(), host: ch.protectionSpace.host);
    return resp ?? ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
  }

  Future<HttpAuthResponse?> onReceivedHttpAuthRequest(InAppWebViewController ctrl, URLAuthenticationChallenge ch) async {
    final host = ch.protectionSpace.host;
    final saved = await ref.read(browserCredentialProvider.notifier).getCredentialsForDomain(host);
    final resp = await BrowserDialogHelper.showHttpAuthDialog(
      context: getContext(), host: host, realm: ch.protectionSpace.realm ?? '',
      initialUser: saved.firstOrNull?.username, initialPass: saved.firstOrNull?.password,
    );
    if (resp?.action == HttpAuthResponseAction.PROCEED && resp!.username.isNotEmpty && resp.password.isNotEmpty) {
      await ref.read(browserCredentialProvider.notifier).saveCredential(domain: host, username: resp.username, password: resp.password);
    }
    return resp ?? HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
  }

  Future<PermissionResponse> onPermissionRequest(InAppWebViewController ctrl, PermissionRequest r) async {
    final action = await BrowserDialogHelper.showPermissionPromptDialog(
      context: getContext(), origin: r.origin.toString(), resources: r.resources,
    );
    return PermissionResponse(resources: r.resources, action: action);
  }
}
