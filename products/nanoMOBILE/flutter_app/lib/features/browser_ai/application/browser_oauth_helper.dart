// browser_oauth_helper.dart — Manejador de autenticación OAuth externa segura.
// QUÉ HACE: Abre flujos de inicio de sesión (Google, Apple, GitHub) en el navegador del sistema.
// CÓMO FUNCIONA: Emplea url_launcher con LaunchMode.externalApplication para evitar el bloqueo 403 de Google WebView.
// POR QUÉ: Google bloquea OAuth en WebViews embebidos; Nano nunca solicita ni almacena credenciales del usuario.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowserOAuthHelper {
  const BrowserOAuthHelper();

  /// User-Agent moderno de Chrome Mobile para evitar que Google detecte el WebView embebido (; wv).
  static const String safeMobileChromeUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

  /// Determina si una URL corresponde a un proveedor de autenticación federada (OAuth).
  static bool isOAuthUrl(Uri url) {
    final host = url.host.toLowerCase();
    return host.contains('accounts.google.com') ||
        host.contains('appleid.apple.com') ||
        host.contains('github.com/login/oauth') ||
        host.contains('login.microsoftonline.com');
  }

  /// Abre la URL en el navegador externo del sistema (Chrome, Firefox, etc.) de manera 100% segura.
  static Future<bool> openInSystemBrowser(Uri url) async {
    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('[BrowserOAuthHelper] Error abriendo navegador del sistema: $e');
    }
    return false;
  }
}
