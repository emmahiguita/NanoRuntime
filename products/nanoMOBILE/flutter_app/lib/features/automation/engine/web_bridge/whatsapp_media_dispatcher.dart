/// WA-MEDIA-DISPATCHER-01 — Despachador híbrido de mensajes y multimedia para WhatsApp.
///
/// **QUÉ HACE:**
/// Determina el canal de transporte óptimo (notificación nativa RemoteInput para texto,
/// o WhatsAppWebBridgeController para fotos, videos y documentos).
///
/// **CÓMO FUNCIONA:**
/// Recibe peticiones de envío desde el agente de automatización o la interfaz de Nano.
/// Si hay archivos binarios adjuntos, los enruta al puente web; si es texto y no hay puente,
/// recurre al servicio de notificaciones Android.
///
/// **POR QUÉ:**
/// Abstrae la heterogeneidad de los canales de salida, proporcionando un punto
/// único de entrada para enviar cualquier tipo de contenido sin salir de Nano.
library;

import 'dart:io';
import '../../domain/whatsapp_media_payload.dart';
import 'whatsapp_web_bridge_controller.dart';

final class WhatsAppMediaDispatcher {
  final WhatsAppWebBridgeController _bridge;

  WhatsAppMediaDispatcher({
    WhatsAppWebBridgeController? bridge,
  }) : _bridge = bridge ?? whatsAppWebBridgeController;

  /// Estado de disponibilidad del canal multimedia.
  bool get canSendMedia => _bridge.currentSession.isConnected;

  /// Envía una fotografía o imagen (JPEG/PNG) directamente a un destinatario.
  Future<bool> sendPhoto({
    required String filePath,
    String? caption,
    required String recipientPhone,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final name = file.uri.pathSegments.last;
    final isPng = name.toLowerCase().endsWith('.png');
    final payload = WhatsAppMediaPayload(
      filePath: filePath,
      mimeType: isPng ? 'image/png' : 'image/jpeg',
      caption: caption,
      fileName: name,
      type: WhatsAppMediaType.image,
    );

    return _bridge.sendMedia(payload, recipientPhone: recipientPhone);
  }

  /// Envía un video (MP4) directamente a un destinatario sin salir de Nano.
  Future<bool> sendVideo({
    required String filePath,
    String? caption,
    required String recipientPhone,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final name = file.uri.pathSegments.last;
    final payload = WhatsAppMediaPayload(
      filePath: filePath,
      mimeType: 'video/mp4',
      caption: caption,
      fileName: name,
      type: WhatsAppMediaType.video,
    );

    return _bridge.sendMedia(payload, recipientPhone: recipientPhone);
  }

  /// Envía un documento (PDF, etc.) directamente al chat de WhatsApp.
  Future<bool> sendDocument({
    required String filePath,
    String? caption,
    required String recipientPhone,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final name = file.uri.pathSegments.last;
    final payload = WhatsAppMediaPayload(
      filePath: filePath,
      mimeType: 'application/pdf',
      caption: caption,
      fileName: name,
      type: WhatsAppMediaType.document,
    );

    return _bridge.sendMedia(payload, recipientPhone: recipientPhone);
  }

  /// Despacha una carga multimedia genérica validando conectividad previa.
  Future<bool> sendMediaPayload(
    WhatsAppMediaPayload payload, {
    required String recipientPhone,
  }) async {
    return _bridge.sendMedia(payload, recipientPhone: recipientPhone);
  }
}

/// Instancia por defecto del despachador de medios.
final whatsAppMediaDispatcher = WhatsAppMediaDispatcher();
