/// Convierte estados de la página Web sin inferir una conexión desde el switch.
library;

import '../../domain/whatsapp_media_payload.dart';

// Reutiliza las señales reales del script de sesión; no recarga ni vincula nada.
WhatsAppWebSessionInfo decodeWhatsAppWebSession(Map<String, dynamic> data) {
  final statusStr = data['status'] as String? ?? 'disconnected';
  final qrDataUrl = data['qrDataUrl'] as String?;
  final qrDataRef = data['qrDataRef'] as String?;
  final newStatus = switch (statusStr) {
    'waitingForQr' => WhatsAppWebSessionStatus.waitingForQr,
    'syncing' => WhatsAppWebSessionStatus.syncing,
    'connected' => WhatsAppWebSessionStatus.connected,
    _ => WhatsAppWebSessionStatus.disconnected,
  };
  return WhatsAppWebSessionInfo(
    status: newStatus,
    lastActive: DateTime.now(),
    qrDataUrl: qrDataUrl,
    qrDataRef: qrDataRef,
  );
}
