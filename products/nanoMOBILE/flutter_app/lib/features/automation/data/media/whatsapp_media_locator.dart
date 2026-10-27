import '../../domain/incoming_attachment.dart';

/// Una hora no vincula un archivo a un mensaje ni a una cuenta de WhatsApp.
/// No escanea todas las carpetas para terminar atribuyendo el medio de otro chat.
/// Los paths/URI explícitos entregados por Android o Web se procesan por su ruta real.
abstract final class WhatsAppMediaLocator {
  // Conserva las firmas de los consumidores; responde «sin vínculo» honestamente.
  // Cero IO e Isolates cuando solo se dispone de una coincidencia temporal.
  static Future<IncomingAttachment> locateImage({
    int? referenceTimestampMs,
  }) async =>
      _unbound(AttachmentType.image, referenceTimestampMs, 'image/jpeg');

  static Future<IncomingAttachment> locateVideo({
    int? referenceTimestampMs,
  }) async => _unbound(AttachmentType.video, referenceTimestampMs, 'video/mp4');

  static Future<IncomingAttachment> locateVoiceNote({
    int? referenceTimestampMs,
  }) async =>
      _unbound(AttachmentType.voice, referenceTimestampMs, 'audio/opus');

  // No inventa un path, un timestamp de observación ni una confianza «exacta».
  static IncomingAttachment _unbound(
    AttachmentType type,
    int? timestamp,
    String mime,
  ) => IncomingAttachment(
    type: type,
    mimeType: mime,
    observedAt: timestamp ?? 0,
    resolutionStatus: AttachmentResolutionStatus.ambiguous,
    confidence: AttachmentConfidence.ambiguous,
  );
}
