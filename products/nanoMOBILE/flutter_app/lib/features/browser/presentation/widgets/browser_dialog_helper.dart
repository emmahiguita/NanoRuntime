import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/features/browser/application/browser_context_extractor.dart';
import 'package:nanoai/features/browser/domain/browser_tab_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Diálogos de soporte para el navegador web Nano AI.
class BrowserDialogHelper {
  const BrowserDialogHelper._();

  /// Abre diálogo para buscar o escribir una nueva URL
  static void showUrlEditDialog({
    required BuildContext context,
    required String currentUrl,
    required ValueChanged<String> onSubmitted,
  }) {
    final textCtrl = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text(
              'Buscar o escribir URL',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: TextField(
            controller: textCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
            ),
            onSubmitted: (val) {
              Navigator.pop(dialogCtx);
              if (val.trim().isNotEmpty) {
                onSubmitted(val.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (textCtrl.text.trim().isNotEmpty) {
                onSubmitted(textCtrl.text.trim());
              }
            },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              tab.isSecure ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: tab.isSecure ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              tab.isSecure ? 'Conexión Segura' : 'Conexión Insegura',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tab.displayHost.isNotEmpty ? tab.displayHost : tab.url,
              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              tab.isSecure
                  ? 'El certificado de este sitio es válido. Tu conexión con el servidor remoto está cifrada mediante TLS. La información personal o contraseñas permanecen privadas.'
                  : 'Este sitio web no provee una conexión cifrada segura (HTTPS). Los datos transmitidos pueden no ser privados.',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
  }

  /// Modal interactivo de Búho IA para analizar la página web
  static void showOwlAssistantDialog({
    required BuildContext context,
    required BrowserTabModel tab,
    required InAppWebViewController? controller,
    required void Function(String prompt) onSendToChat,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0B1626),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 1.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD946EF), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Búho IA — Asistente Web',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tab.title.isNotEmpty ? tab.title : tab.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Acciones inteligentes con el contenido de esta página:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
            ),
            const SizedBox(height: 12),
            _buildOwlTile(
              sheetCtx,
              icon: Icons.summarize_rounded,
              label: 'Resumir contenido principal',
              accent: const Color(0xFF38BDF8),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (controller != null) {
                  final text = await BrowserContextExtractor.getSanitizedContext(
                    controller: controller,
                    sourceUrl: tab.url,
                    pageTitle: tab.title,
                  );
                  onSendToChat('Resume de forma clara el contenido principal de esta página:\n\n${text ?? tab.url}');
                }
              },
            ),
            _buildOwlTile(
              sheetCtx,
              icon: Icons.lightbulb_rounded,
              label: 'Extraer puntos clave y conclusiones',
              accent: const Color(0xFF10B981),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (controller != null) {
                  final text = await BrowserContextExtractor.getSanitizedContext(
                    controller: controller,
                    sourceUrl: tab.url,
                    pageTitle: tab.title,
                  );
                  onSendToChat('Extrae las ideas clave y conclusiones de:\n\n${text ?? tab.url}');
                }
              },
            ),
            _buildOwlTile(
              sheetCtx,
              icon: Icons.translate_rounded,
              label: 'Traducir al español y explicar',
              accent: const Color(0xFFF59E0B),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (controller != null) {
                  final text = await BrowserContextExtractor.getSanitizedContext(
                    controller: controller,
                    sourceUrl: tab.url,
                    pageTitle: tab.title,
                  );
                  onSendToChat('Traduce al español y explica este contenido:\n\n${text ?? tab.url}');
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Widget _buildOwlTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF152336),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo de confirmación para enlaces de apps externas
  static void promptExternalApp(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Aplicación Externa', style: TextStyle(color: Colors.white)),
        content: Text(
          'Esta página solicita abrir en una aplicación externa:\n\n$url',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.tryParse(url);
              if (uri != null) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              }
            },
            child: const Text('ABRIR'),
          ),
        ],
      ),
    );
  }

  /// Diálogo de autenticación HTTP Basic / Digest
  static Future<HttpAuthResponse?> showHttpAuthDialog({
    required BuildContext context,
    required String host,
    required String realm,
    String? initialUser,
    String? initialPass,
  }) async {
    final userCtrl = TextEditingController(text: initialUser ?? '');
    final passCtrl = TextEditingController(text: initialPass ?? '');
    bool obscure = true;

    return showDialog<HttpAuthResponse>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFF38BDF8), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Autenticación Requerida',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El sitio $host solicita credenciales${realm.isNotEmpty ? ' ($realm)' : ''}:',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: const Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                ctx,
                HttpAuthResponse(action: HttpAuthResponseAction.CANCEL),
              ),
              child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final u = userCtrl.text.trim();
                final p = passCtrl.text;
                Navigator.pop(
                  ctx,
                  HttpAuthResponse(
                    action: HttpAuthResponseAction.PROCEED,
                    username: u,
                    password: p,
                  ),
                );
              },
              child: const Text('INICIAR SESIÓN'),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo de advertencia por fallo de certificado SSL / TLS
  static Future<ServerTrustAuthResponse?> showSslWarningDialog({
    required BuildContext context,
    required String host,
  }) async {
    return showDialog<ServerTrustAuthResponse>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
        ),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text(
              'Advertencia de Certificado SSL',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'La conexión con "$host" no es privada ni segura.\n\nEl certificado de seguridad es inválido, ha caducado o está autofirmado. Continuar podría permitir que atacantes intercepten tus contraseñas, mensajes o credenciales.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(
              ctx,
              ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL),
            ),
            child: const Text('Volver a Seguridad (Recomendado)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED),
            ),
            child: const Text(
              'Continuar de todos modos',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Diálogo de confirmación para solicitudes de permisos web (Cámara, Micrófono, etc.)
  static Future<PermissionResponseAction> showPermissionPromptDialog({
    required BuildContext context,
    required String origin,
    required List<PermissionResourceType> resources,
  }) async {
    final resLabels = resources.map((r) => r.toString().split('.').last).join(', ');
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.perm_device_information_rounded, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text(
              'Solicitud de Permisos Web',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'El sitio "$origin" solicita acceder a tus recursos de hardware:\n\n• $resLabels\n\n¿Deseas conceder acceso?',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('DENEGAR', style: TextStyle(color: Color(0xFFEF4444))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('PERMITIR'),
          ),
        ],
      ),
    );

    return allowed == true ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY;
  }

  /// Diálogo informativo cuando el firewall bloquea una URL prohibida
  static void showFirewallBlockedDialog({
    required BuildContext context,
    required String url,
    required String reason,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text(
              'Bloqueado por Firewall Nano AI',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'El acceso a "$url" ha sido bloqueado por razones de seguridad.\n\nMotivo: $reason\n\nProtección activa contra SSRF, acceso a red local y puertos internos de Nano Runtime.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }
}

