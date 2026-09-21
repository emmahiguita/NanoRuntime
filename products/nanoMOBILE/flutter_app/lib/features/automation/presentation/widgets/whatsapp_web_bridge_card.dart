/// WA-WEB-BRIDGE-CARD-01 — Tarjeta de configuración para el puente multimedia de WhatsApp Web.
///
/// **QUÉ HACE:**
/// Muestra el estado en vivo de la conexión Multi-Device de WhatsApp Web y permite
/// al usuario abrir la ventana modal para escanear el código QR.
///
/// **CÓMO FUNCIONA:**
/// Observa reactivamente whatsAppWebBridgeController.sessionStream y presenta un chip
/// de estado con acciones directas para conectar, ver o recargar la sesión.
///
/// **POR QUÉ:**
/// Provee una experiencia de usuario clara y centralizada para habilitar el envío
/// de fotos, videos y documentos sin salir de Nano (< 200 LOC, SOLID - SRP).
library;

import 'package:flutter/material.dart';
import '../../domain/whatsapp_media_payload.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import '../automation_visual_theme.dart';
import 'settings_tile_components.dart';
import 'whatsapp_web_link_view.dart';

class WhatsAppWebBridgeCard extends StatelessWidget {
  const WhatsAppWebBridgeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return StreamBuilder<WhatsAppWebSessionInfo>(
      stream: whatsAppWebBridgeController.sessionStream,
      initialData: whatsAppWebBridgeController.currentSession,
      builder: (context, snapshot) {
        final session = snapshot.data ?? whatsAppWebBridgeController.currentSession;
        final isConnected = session.isConnected;
        final isWaitingQr = session.status == WhatsAppWebSessionStatus.waitingForQr;

        final statusText = switch (session.status) {
          WhatsAppWebSessionStatus.connected => 'Conectado — Envío de fotos y videos habilitado',
          WhatsAppWebSessionStatus.waitingForQr => 'Esperando escaneo de código QR',
          WhatsAppWebSessionStatus.syncing => 'Sincronizando chats...',
          WhatsAppWebSessionStatus.error => 'Error de conexión — Toca para reintentar',
          WhatsAppWebSessionStatus.disconnected => 'Inactivo — Toca para vincular dispositivo',
        };

        final statusColor = isConnected
            ? Colors.green
            : (isWaitingQr ? Colors.amber : visual.textMuted);

        return SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.perm_media_outlined,
              title: 'Canal Multimedia (Fotos y Videos)',
              subtitle: statusText,
              trailing: Chip(
                avatar: CircleAvatar(
                  radius: 4,
                  backgroundColor: statusColor,
                ),
                label: Text(
                  isConnected ? 'ACTIVO' : 'VINCULAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isConnected ? Colors.green : visual.accent,
                  ),
                ),
                backgroundColor: isConnected
                    ? Colors.green.withValues(alpha: 0.15)
                    : visual.accent.withValues(alpha: 0.15),
                visualDensity: VisualDensity.compact,
              ),
              onTap: () => WhatsAppWebLinkView.show(context),
            ),
          ],
        );
      },
    );
  }
}
