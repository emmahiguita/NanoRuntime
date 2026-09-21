/// WA-MEDIA-DOMAIN-01 — Modelo de dominio para mensajes multimedia de WhatsApp.
///
/// **QUÉ HACE:**
/// Define las estructuras de datos inmutables para el despacho de archivos
/// multimedia (fotos, videos, notas de voz, documentos) y el estado de sesión Web.
///
/// **CÓMO FUNCIONA:**
/// Encapsula rutas de archivo local, bytes en memoria, tipos MIME y metadatos
/// requeridos para inyectar en el cliente de WhatsApp Web o APIs compatibles.
///
/// **POR QUÉ:**
/// Separa los contratos de datos del transporte físico (Clean Architecture - Domain Layer).
library;

import 'dart:typed_data';

/// Tipo de contenido multimedia soportado para envío en WhatsApp.
enum WhatsAppMediaType {
  image,
  video,
  audio,
  document,
}

/// Estado del ciclo de vida de la sesión de WhatsApp Web vinculada.
enum WhatsAppWebSessionStatus {
  disconnected,
  waitingForQr,
  syncing,
  connected,
  error,
}

/// Carga útil de un mensaje multimedia listo para ser despachado.
final class WhatsAppMediaPayload {
  final String? filePath;
  final Uint8List? bytes;
  final String mimeType;
  final String? caption;
  final String fileName;
  final WhatsAppMediaType type;

  const WhatsAppMediaPayload({
    this.filePath,
    this.bytes,
    required this.mimeType,
    this.caption,
    required this.fileName,
    required this.type,
  }) : assert(filePath != null || bytes != null, 'Debe proveer filePath o bytes');

  WhatsAppMediaPayload copyWith({
    String? filePath,
    Uint8List? bytes,
    String? mimeType,
    String? caption,
    String? fileName,
    WhatsAppMediaType? type,
  }) {
    return WhatsAppMediaPayload(
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      caption: caption ?? this.caption,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
    );
  }
}

/// Estado de la conexión de WhatsApp Web Multi-Device en Nano.
final class WhatsAppWebSessionInfo {
  final WhatsAppWebSessionStatus status;
  final String? phoneNumber;
  final String? pushName;
  final DateTime? lastActive;
  final String? errorMessage;
  final String? qrDataUrl;
  final String? qrDataRef;

  const WhatsAppWebSessionInfo({
    required this.status,
    this.phoneNumber,
    this.pushName,
    this.lastActive,
    this.errorMessage,
    this.qrDataUrl,
    this.qrDataRef,
  });

  bool get isConnected => status == WhatsAppWebSessionStatus.connected;
}
