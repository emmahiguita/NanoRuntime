import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../domain/browser_site_profile.dart';
import '../../infrastructure/browser_scripts.dart';
import '../../infrastructure/browser_web_compatibility_bridge.dart';

/// Sincroniza la identidad móvil/desktop antes de que salga la petición HTTP.
///
/// Cambia User-Agent y Client Hints como una sola operación, instala el viewport
/// en document-start y recarga solo cuando una preferencia realmente cambia.
class BrowserWebIdentityCoordinator {
  BrowserWebIdentityCoordinator({
    required this.isAlive,
    required this.userDesktopMode,
  });

  static const _viewportGroup = 'nano_viewport';
  final bool Function() isAlive;
  final bool Function() userDesktopMode;
  final BrowserWebCompatibilityBridge _bridge =
      const BrowserWebCompatibilityBridge();
  bool _desktopApplied = false;
  int _revision = 0;

  /// Calcula el modo efectivo sin cambiar la preferencia global del usuario.
  bool usesDesktop(String url) => BrowserSiteProfile.usesDesktop(
    url: url,
    userDesktopMode: userDesktopMode(),
  );

  /// La primera carga desktop se retrasa hasta configurar Client Hints nativos.
  bool mustPrepareInitial(String url, {required bool initialized}) =>
      !initialized && usesDesktop(url);

  /// Configura la vista recién creada y después inicia su primera navegación.
  Future<void> loadInitial(
    InAppWebViewController controller,
    String url,
  ) async {
    if (!await _apply(controller, desktop: usesDesktop(url))) return;
    if (isAlive()) {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
  }

  /// Intercepta solo transiciones que necesitan cambiar la identidad HTTP.
  Future<bool> intercept(
    InAppWebViewController controller,
    URLRequest request,
  ) async {
    final url = request.url?.toString();
    if (url == null) return false;
    final desktop = usesDesktop(url);
    if (desktop == _desktopApplied) return false;
    final applied = await _apply(controller, desktop: desktop);
    if (!applied || !isAlive()) return true;
    await controller.loadUrl(urlRequest: request);
    return true;
  }

  /// Aplica un cambio explícito del menú y conserva el documento mediante reload.
  Future<void> applyPreference(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    final revision = ++_revision;
    if (!await _apply(controller, desktop: usesDesktop(currentUrl))) return;
    if (isAlive() && revision == _revision) await controller.reload();
  }

  /// Añade el viewport antes de cargar y actualiza la identidad nativa atómica.
  Future<bool> _apply(
    InAppWebViewController controller, {
    required bool desktop,
  }) async {
    try {
      final nativeReady = await _bridge.setDesktopIdentity(
        controller,
        enabled: desktop,
      );
      if (!nativeReady || !isAlive()) return false;
      await controller.removeUserScriptsByGroupName(groupName: _viewportGroup);
      if (!isAlive()) return false;
      if (desktop) await controller.addUserScript(userScript: viewportScript);
      _desktopApplied = desktop;
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Ajusta el lienzo desktop a pantallas pequeñas sin tocar el CSS de WhatsApp.
  static UserScript get viewportScript => UserScript(
    groupName: _viewportGroup,
    source: BrowserScripts.desktopViewportAdapterScript,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );
}
