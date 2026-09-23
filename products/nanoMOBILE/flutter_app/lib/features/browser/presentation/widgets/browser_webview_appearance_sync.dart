import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../infrastructure/browser_scripts.dart';

/// Sincroniza modo móvil/escritorio antes de recargar la vista.
/// Una revisión descarta cambios antiguos y conserva scripts ajenos al viewport.
class BrowserWebViewAppearanceSync {
  static const _viewportGroup = 'nano_viewport';
  int _revision = 0;

  static UserScript viewportScript(bool desktop) => UserScript(
    groupName: _viewportGroup,
    source: desktop
        ? BrowserScripts.desktopViewportAdapterScript
        : BrowserScripts.mobileViewportAdapterScript,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );

  Future<void> apply(
    InAppWebViewController controller, {
    required bool desktop,
    required bool Function() isAlive,
  }) async {
    final revision = ++_revision;
    bool current() => isAlive() && revision == _revision;
    try {
      // null/vacío no restablece el UA en Android; recuperar el valor nativo real.
      final userAgent = desktop
          ? BrowserScripts.desktopUserAgent
          : await InAppWebViewController.getDefaultUserAgent();
      if (!current()) return;
      await controller.setSettings(
        settings: InAppWebViewSettings(
          userAgent: userAgent,
          preferredContentMode: desktop
              ? UserPreferredContentMode.DESKTOP
              : UserPreferredContentMode.MOBILE,
          useWideViewPort: true,
          loadWithOverviewMode: true,
        ),
      );
      if (!current()) return;
      await controller.removeUserScriptsByGroupName(groupName: _viewportGroup);
      if (!current()) return;
      // En móvil manda el viewport del sitio, sin un script de escritorio residual.
      if (desktop) await controller.addUserScript(userScript: viewportScript(true));
      if (current()) await controller.reload();
    } on PlatformException {
      // Cerrar una pestaña durante el cambio invalida el controlador nativo.
    }
  }
}
