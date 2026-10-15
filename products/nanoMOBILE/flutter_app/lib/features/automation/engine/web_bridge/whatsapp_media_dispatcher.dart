/// Fachada compatible de solicitudes multimedia; no anuncia entregas ficticias.
/// El transporte Web está deshabilitado hasta verificar destino, preview y commit.
/// No existe fallback a notificaciones para archivos: RemoteInput solo admite texto.
library;

import 'dart:io';
import '../../domain/whatsapp_media_payload.dart';
import 'whatsapp_web_bridge_controller.dart';

final class WhatsAppMediaDispatcher {
  final WhatsAppWebBridgeController _bridge;

  WhatsAppMediaDispatcher({WhatsAppWebBridgeController? bridge})
    : _bridge = bridge ?? whatsAppWebBridgeController;

  /// Conectado no significa que exista un envío multimedia verificable.
  bool get canSendMedia => false;

  /// Valida el archivo solicitado; false indica que el canal no admite el envío.
  Future<bool> sendPhoto({
    required String filePath,
    String? caption,
    required String recipientPhone,
  }) async {
    if (!canSendMedia) return false;
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

  /// Solicita un video sin prometer entrega ni cambiar a otro transporte.
  Future<bool> sendVideo({
    required String filePath,
    String? caption,
    required String recipientPhone,
  }) async {
    if (!canSendMedia) return false;
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

  /// Conserva la solicitud de documentos; no la confunde con un envío confirmado.
  Future<bool> sendDocument({
    required String filePath,
    String? caption,
    required String recipientPhone,
  }) async {
    if (!canSendMedia) return false;
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
