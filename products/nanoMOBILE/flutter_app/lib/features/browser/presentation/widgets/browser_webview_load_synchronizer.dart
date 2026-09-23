import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_credential_notifier.dart';
import 'package:nanoai/features/browser/application/browser_history_notifier.dart';
import 'package:nanoai/features/browser/application/browser_pip_notifier.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';

/// Sincroniza el estado del navegador tras cargar una página.
///
/// Agrupa lecturas asíncronas del WebView y corta el flujo si la vista muere;
/// esto evita actualizaciones tardías y mantiene el manejador de eventos pequeño.
class BrowserWebViewLoadSynchronizer {
  const BrowserWebViewLoadSynchronizer({
    required this.ref,
    required this.tab,
    required this.isAlive,
    required this.isDesktopMode,
    required this.isDarkModeWeb,
    required this.currentZoom,
  });

  final WidgetRef ref;
  final BrowserTabModel tab;
  final bool Function() isAlive;
  final bool isDesktopMode;
  final bool isDarkModeWeb;
  final double currentZoom;

  Future<void> synchronize(InAppWebViewController controller, WebUri? url) async {
    if (!isAlive()) return;
    try {
      final title = await controller.getTitle();
      if (!isAlive()) return;
      final canBack = await controller.canGoBack();
      if (!isAlive()) return;
      final canForward = await controller.canGoForward();
      if (!isAlive()) return;

      if (url != null) {
        await _syncPage(controller, url, title, canBack, canForward);
      }
      if (!isAlive()) {
        return;
      }
      await _installPageScripts(controller);
      if (isAlive() && ref.read(browserTabProvider).activeTabId == tab.id) {
        ref.read(browserPipProvider.notifier).attachController(controller);
      }
    } on PlatformException {
      // Una vista nativa cerrada no debe dejar una excepción asíncrona sin manejar.
    }
  }

  Future<void> _syncPage(
    InAppWebViewController controller,
    WebUri url,
    String? title,
    bool canBack,
    bool canForward,
  ) async {
    final address = url.toString();
    ref
        .read(browserTabProvider.notifier)
        .updateTabById(
          tab.id,
          url: address,
          title: title?.isNotEmpty == true ? title : null,
          isLoading: false,
          progress: 1.0,
          canGoBack: canBack,
          canGoForward: canForward,
        );
    ref.read(browserHistoryProvider.notifier).recordVisit(address, title ?? '');

    final host = url.uriValue.host;
    if (host.isEmpty) return;
    final credentials = await ref
        .read(browserCredentialProvider.notifier)
        .getCredentialsForDomain(host);
    if (!isAlive() || credentials.isEmpty) return;
    // No inyectar credenciales si una redirección cambió de origen durante la lectura.
    final current = await controller.getUrl();
    if (!isAlive() || current?.uriValue.host != host) return;
    await controller.evaluateJavascript(
      source: BrowserScripts.buildAutofillScript(
        credentials.first.username,
        credentials.first.password,
      ),
    );
  }

  Future<void> _installPageScripts(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: BrowserScripts.pinchZoomEngineScript);
      if (!isAlive()) return;
      if (isDesktopMode) {
        await controller.evaluateJavascript(source: BrowserScripts.desktopViewportAdapterScript);
      }
      if (!isAlive()) return;
      final zoom =
          ref
              .read(browserTabProvider)
              .tabs
              .where((item) => item.id == tab.id)
              .firstOrNull
              ?.zoomLevel ??
          tab.zoomLevel;
      if (zoom != 1.0) {
        await controller.evaluateJavascript(source: BrowserScripts.setZoomLevelScript(zoom));
      }
      if (!isAlive()) return;
      if (isDarkModeWeb) {
        await controller.evaluateJavascript(
          source:
              "if (!document.getElementById('__nano_dark_style')) {"
              "${BrowserScripts.toggleDarkModeWebScript}}",
        );
      }
    } catch (_) {
      // Un sitio puede bloquear JavaScript; la página permanece navegable.
    }
  }
}
