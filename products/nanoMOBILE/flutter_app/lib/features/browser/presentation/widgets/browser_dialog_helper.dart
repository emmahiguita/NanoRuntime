import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_owl_assistant_sheet.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_security_dialogs.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fachada de diálogos de soporte y navegación para el navegador web Nano AI.
/// 
/// - QUÉ HACE: Abre diálogos para edición de URL, enlaces de apps externas, SSL y búho IA.
/// - CÓMO FUNCIONA: Despacha [showDialog] y delega diálogos de seguridad en [BrowserSecurityDialogs].
/// - POR QUÉ: Reduce el acoplamiento y cumple el límite estricto de <200 líneas.
class BrowserDialogHelper {
  const BrowserDialogHelper._();

  /// Abre diálogo para buscar o escribir una nueva URL
  static void showUrlEditDialog({required BuildContext context, required String currentUrl, required ValueChanged<String> onSubmitted}) {
    final textCtrl = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 20),
          SizedBox(width: 8),
          Text('Buscar o escribir URL', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: TextField(
          controller: textCtrl, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'https://...', hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true, fillColor: const Color(0xFF1E293B), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
          ),
          onSubmitted: (val) { Navigator.pop(dialogCtx); if (val.trim().isNotEmpty) onSubmitted(val.trim()); },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () { Navigator.pop(dialogCtx); if (textCtrl.text.trim().isNotEmpty) onSubmitted(textCtrl.text.trim()); },
            child: const Text('IR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Diálogo informativo de seguridad y certificado SSL
  static void showSslDialog(BuildContext context, BrowserTabModel tab) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(tab.isSecure ? Icons.lock_rounded : Icons.lock_open_rounded, color: tab.isSecure ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 20),
          const SizedBox(width: 8),
          Text(tab.isSecure ? 'Conexión Segura' : 'Conexión Insegura', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tab.displayHost.isNotEmpty ? tab.displayHost : tab.url, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            tab.isSecure
                ? 'El certificado de este sitio es válido. Tu conexión está cifrada mediante TLS y tus datos permanecen privados.'
                : 'Este sitio web no provee una conexión cifrada segura (HTTPS). Los datos transmitidos pueden no ser privados.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ENTENDIDO', style: TextStyle(color: Color(0xFF10B981)))),
        ],
      ),
    );
  }

  /// Diálogo de confirmación para enlaces de apps externas
  static void promptExternalApp(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aplicación Externa', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Esta página solicita abrir en una aplicación externa:\n\n$url', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.tryParse(url);
              if (uri != null) { try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {} }
            },
            child: const Text('ABRIR'),
          ),
        ],
      ),
    );
  }

  /// Abre el asistente Búho IA para la pestaña activa
  static void showOwlAssistantDialog({required BuildContext context, required BrowserTabModel tab, required InAppWebViewController? controller, required void Function(String prompt) onSendToChat}) {
    BrowserOwlAssistantSheet.show(context, tab: tab, controller: controller);
  }

  // Delegaciones a BrowserSecurityDialogs para compatibilidad
  static Future<HttpAuthResponse?> showHttpAuthDialog({required BuildContext context, required String host, required String realm, String? initialUser, String? initialPass}) =>
      BrowserSecurityDialogs.showHttpAuthDialog(context: context, host: host, realm: realm, initialUser: initialUser, initialPass: initialPass);

  static Future<ServerTrustAuthResponse?> showSslWarningDialog({required BuildContext context, required String host}) =>
      BrowserSecurityDialogs.showSslWarningDialog(context: context, host: host);

  static Future<PermissionResponseAction> showPermissionPromptDialog({required BuildContext context, required String origin, required List<PermissionResourceType> resources}) =>
      BrowserSecurityDialogs.showPermissionPromptDialog(context: context, origin: origin, resources: resources);

  static void showFirewallBlockedDialog({required BuildContext context, required String url, required String reason}) =>
      BrowserSecurityDialogs.showFirewallBlockedDialog(context: context, url: url, reason: reason);
}
