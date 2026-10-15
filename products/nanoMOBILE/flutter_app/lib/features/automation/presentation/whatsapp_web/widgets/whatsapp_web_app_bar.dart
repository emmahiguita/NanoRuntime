// whatsapp_web_app_bar.dart
//
// QUÉ HACE:
// Barra de aplicación superior para la vista WhatsApp Web en Nano Mobile.
//
// CÓMO FUNCIONA:
// - Muestra dinámicamente el botón de retroceso adecuado (según si hay conversación activa o no).
// - Provee el indicador de estado de sesión conectada con señal visual verde.
// - Permite alternar conmutativamente entre la vista móvil adaptada y la web original.
// - Provee un botón de recarga rápida para refrescar la sesión si WhatsApp experimenta caídas.
//
// POR QUÉ:
// Aplica SRP aislando el componente visual de la barra fuera del Scaffold principal.
// Mantiene el código desacoplado, legible y estrictamente bajo 200 líneas.

import 'package:flutter/material.dart';

import '../../../domain/whatsapp_media_payload.dart';

class WhatsAppWebAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final bool isConversationActive;
  final bool isOriginalMode;
  final WhatsAppWebSessionStatus sessionStatus;
  final VoidCallback onBack;
  final VoidCallback onToggleMode;
  final VoidCallback onReload;

  const WhatsAppWebAppBar({
    super.key,
    required this.isDark,
    required this.isConversationActive,
    required this.isOriginalMode,
    required this.sessionStatus,
    required this.onBack,
    required this.onToggleMode,
    required this.onReload,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (sessionStatus) {
      WhatsAppWebSessionStatus.connected => (
        'Sesión conectada',
        const Color(0xFF22C55E),
      ),
      WhatsAppWebSessionStatus.syncing => (
        'Sincronizando mensajes',
        const Color(0xFFF59E0B),
      ),
      WhatsAppWebSessionStatus.waitingForQr => (
        'Esperando vinculación',
        const Color(0xFF3B82F6),
      ),
      WhatsAppWebSessionStatus.error => (
        'Error de conexión',
        const Color(0xFFEF4444),
      ),
      WhatsAppWebSessionStatus.disconnected => (
        'Sesión desconectada',
        const Color(0xFF94A3B8),
      ),
    };

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 4,
        right: 8,
      ),
      color: isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.95),
      child: Row(
        children: [
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: Icon(
              isConversationActive
                  ? Icons.arrow_back
                  : Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
            tooltip: isConversationActive ? 'Volver a chats' : 'Volver a Nano',
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConversationActive ? 'WhatsApp Chat' : 'WhatsApp Web',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isOriginalMode
                  ? Icons.phone_android_rounded
                  : Icons.desktop_windows_outlined,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            tooltip: isOriginalMode
                ? 'Activar vista móvil'
                : 'Ver modo web original',
            onPressed: onToggleMode,
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            tooltip: 'Recargar página',
            onPressed: onReload,
          ),
        ],
      ),
    );
  }
}
