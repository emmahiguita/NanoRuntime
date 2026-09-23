import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Diálogos de seguridad, autenticación y permisos para el WebView.
/// 
/// - QUÉ HACE: Presenta modales para autenticación HTTP, avisos SSL, permisos web y firewall.
/// - CÓMO FUNCIONA: Muestra alertas con [AlertDialog] personalizados y devuelve las respuestas nativas del plugin.
/// - POR QUÉ: Aplica SRP separando la seguridad del WebView de los diálogos de navegación (<200 líneas).
class BrowserSecurityDialogs {
  const BrowserSecurityDialogs._();

  /// Diálogo de autenticación HTTP Basic / Digest
  static Future<HttpAuthResponse?> showHttpAuthDialog({
    required BuildContext context, required String host, required String realm,
    String? initialUser, String? initialPass,
  }) async {
    final userCtrl = TextEditingController(text: initialUser ?? '');
    final passCtrl = TextEditingController(text: initialPass ?? '');
    bool obscure = true;

    return showDialog<HttpAuthResponse>(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF0284C7), width: 1.2)),
          title: const Row(children: [
            Icon(Icons.security_rounded, color: Color(0xFF38BDF8), size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Autenticación Requerida', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('El sitio $host solicita credenciales${realm.isNotEmpty ? ' ($realm)' : ''}:', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 10),
            TextField(controller: userCtrl, style: const TextStyle(color: Colors.white, fontSize: 12.5), decoration: const InputDecoration(labelText: 'Usuario', filled: true, fillColor: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'Contraseña', filled: true, fillColor: const Color(0xFF1E293B),
                suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16), onPressed: () => setDlgState(() => obscure = !obscure)),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, HttpAuthResponse(action: HttpAuthResponseAction.CANCEL)), child: const Text('CANCELAR')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () => Navigator.pop(ctx, HttpAuthResponse(action: HttpAuthResponseAction.PROCEED, username: userCtrl.text.trim(), password: passCtrl.text)),
              child: const Text('INICIAR SESIÓN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo de advertencia por fallo de certificado SSL / TLS
  static Future<ServerTrustAuthResponse?> showSslWarningDialog({required BuildContext context, required String host}) async {
    return showDialog<ServerTrustAuthResponse>(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFEF4444), width: 1.2)),
        title: const Row(children: [
          Icon(Icons.gpp_bad_rounded, color: Color(0xFFEF4444), size: 22),
          SizedBox(width: 8),
          Text('Advertencia SSL', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Text('La conexión con "$host" no es privada ni segura.\n\nEl certificado es inválido o ha caducado. Continuar podría permitir la interceptación de tus datos.', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL)),
            child: const Text('Volver a Seguridad', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED)),
            child: const Text('Continuar', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  /// Diálogo de confirmación para solicitudes de permisos web
  static Future<PermissionResponseAction> showPermissionPromptDialog({required BuildContext context, required String origin, required List<PermissionResourceType> resources}) async {
    final resLabels = resources.map((r) => r.toString().split('.').last).join(', ');
    final allowed = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2)),
        title: const Row(children: [
          Icon(Icons.perm_device_information_rounded, color: Color(0xFF38BDF8), size: 20),
          SizedBox(width: 8),
          Text('Permisos Web', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Text('El sitio "$origin" solicita acceder a:\n\n• $resLabels\n\n¿Deseas conceder acceso?', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('DENEGAR', style: TextStyle(color: Color(0xFFEF4444)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('PERMITIR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return allowed == true ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY;
  }

  /// Diálogo informativo cuando el firewall bloquea una URL prohibida
  static void showFirewallBlockedDialog({required BuildContext context, required String url, required String reason}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFEF4444), width: 1.2)),
        title: const Row(children: [
          Icon(Icons.shield_rounded, color: Color(0xFFEF4444), size: 20),
          SizedBox(width: 8),
          Text('Bloqueado por Firewall', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Text('El acceso a "$url" ha sido bloqueado por seguridad.\n\nMotivo: $reason', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
