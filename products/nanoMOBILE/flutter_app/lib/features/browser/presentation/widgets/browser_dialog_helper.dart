import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/browser_tab_model.dart';
import 'browser_connection_dialog.dart';
import 'browser_security_dialogs.dart';
import 'browser_url_edit_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fachada compatible de diálogos: conserva permisos y advertencias de seguridad.
/// Solo presentación; no debilita firewall, validación de TLS ni autenticación.
class BrowserDialogHelper {
  const BrowserDialogHelper._();

  /// El diálogo posee su controlador; la página recibe el resultado si sigue montada.
  static Future<void> showUrlEditDialog({
    required BuildContext context,
    required String currentUrl,
    required ValueChanged<String> onSubmitted,
  }) async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => BrowserUrlEditDialog(initialUrl: currentUrl),
    );
    if (context.mounted && input != null) onSubmitted(input);
  }

  static void showSslDialog(BuildContext context, BrowserTabModel tab) {
    BrowserConnectionDialog.show(context, tab);
  }

  /// La apertura externa siempre requiere confirmación del usuario.
  /// Cierra el Navigator del diálogo, no la ruta del navegador por accidente.
  static Future<void> promptExternalApp(
    BuildContext context,
    String url,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Abrir aplicación externa'),
        content: Text('Esta página solicita abrir otra aplicación:\n\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // El fallo no se trata como éxito; se comunica a continuación.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la aplicación externa.'),
        ),
      );
    }
  }

  /// Delegaciones intactas: siguen usando los controles de seguridad existentes.
  static Future<HttpAuthResponse?> showHttpAuthDialog({
    required BuildContext context,
    required String host,
    required String realm,
    String? initialUser,
    String? initialPass,
  }) => BrowserSecurityDialogs.showHttpAuthDialog(
    context: context,
    host: host,
    realm: realm,
    initialUser: initialUser,
    initialPass: initialPass,
  );

  static Future<ServerTrustAuthResponse?> showSslWarningDialog({
    required BuildContext context,
    required String host,
  }) =>
      BrowserSecurityDialogs.showSslWarningDialog(context: context, host: host);

  static Future<PermissionResponseAction> showPermissionPromptDialog({
    required BuildContext context,
    required String origin,
    required List<PermissionResourceType> resources,
  }) => BrowserSecurityDialogs.showPermissionPromptDialog(
    context: context,
    origin: origin,
    resources: resources,
  );

  static void showFirewallBlockedDialog({
    required BuildContext context,
    required String url,
    required String reason,
  }) => BrowserSecurityDialogs.showFirewallBlockedDialog(
    context: context,
    url: url,
    reason: reason,
  );
}
