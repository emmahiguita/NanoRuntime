// tiktok_shortcut_button.dart
//
// QUÉ HACE: acceso directo dedicado a TikTok en el Centro de Mensajería.
// CÓMO FUNCIONA: botón circular iOS Frosted Glass con el logo de la marca;
// al tocarlo abre la bandeja de mensajes de TikTok en el navegador integrado
// de Nano (misma sesión iniciada con Google) vía ruta `/browser?url=`.
// POR QUÉ: la sesión vive en las cookies del WebView, así que el acceso
// directo reutiliza el login sin pedir credenciales y conecta directo con
// el flujo de mensajería (DMs) para automatizar respuestas.

import 'package:flutter/material.dart';
import '../../domain/messaging_platform.dart';
import '../tiktok_web/tiktok_web_screen.dart';
import 'messaging_platform_icon.dart';

class TikTokShortcutButton extends StatelessWidget {
  /// Bandeja de mensajes de TikTok (punto de entrada del bridge real).
  static const String messagesUrl = 'https://www.tiktok.com/messages';

  const TikTokShortcutButton({super.key});

  /// Abre la pantalla de mensajes TikTok con el bridge de conversaciones.
  static void navigateTo(BuildContext context) {
    TikTokWebScreen.navigateTo(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.48)
        : Colors.white.withValues(alpha: 0.45);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.66);

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => navigateTo(context),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: glassBg,
            shape: BoxShape.circle,
            border: Border.all(color: glassBorder, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: MessagingPlatformIcon(
              platform: MessagingPlatform.tiktok,
              size: 20,
              borderRadius: 5,
            ),
          ),
        ),
      ),
    );

    return Tooltip(message: 'TikTok — Mensajes', child: button);
  }
}
