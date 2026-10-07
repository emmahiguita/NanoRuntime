// incoming_attachment.dart
//
// QUÉ HACE:
// Representa adjuntos multimedia reales (audio, voz, imagen, video, documento)
// interceptados desde WhatsApp u otros canales de mensajería.
//
// CÓMO FUNCIONA:
// Encapsula ruta local en disco, tipo MIME, timestamps, estado de resolución,
// nivel de confianza y transcripción/comprensión semántica sin datos simulados.
//
// POR QUÉ:
// Cumple con la separación limpia "MEDIA DETECTADA ≠ MEDIA COMPRENDIDA" y SOLID.

library;

enum AttachmentType { voice, audio, image, video, document }

enum AttachmentResolutionStatus {
  detected,
  resolved,
  processing,
  processed,
  ambiguous,
  notFound,
  unsupported,
  failed,
}

enum AttachmentConfidence {
  resolvedExact,
  resolvedHighConfidence,
  ambiguous,
  notFound,
}

final class IncomingAttachment {
  final AttachmentType type;
  final String? localPath;
  final String mimeType;
  final int observedAt;
  final String source;
  final int? durationMs;
  final AttachmentResolutionStatus resolutionStatus;
  final AttachmentConfidence confidence;
  final String? transcribedText;
  final String? visionDescription;

  const IncomingAttachment({
    required this.type,
    this.localPath,
    this.mimeType = '',
    required this.observedAt,
    this.source = 'whatsapp',
    this.durationMs,
    this.resolutionStatus = AttachmentResolutionStatus.detected,
    this.confidence = AttachmentConfidence.notFound,
    this.transcribedText,
    this.visionDescription,
  });

  bool get isResolved =>
      localPath != null &&
      localPath!.isNotEmpty &&
      (confidence == AttachmentConfidence.resolvedExact ||
          confidence == AttachmentConfidence.resolvedHighConfidence);

  bool get transcriptionAvailable =>
      type == AttachmentType.voice &&
      transcribedText != null &&
      transcribedText!.trim().isNotEmpty;

  bool get visionAnalysisAvailable =>
      type == AttachmentType.image &&
      visionDescription != null &&
      visionDescription!.trim().isNotEmpty;

  IncomingAttachment copyWith({
    AttachmentType? type,
    String? localPath,
    String? mimeType,
    int? observedAt,
    String? source,
    int? durationMs,
    AttachmentResolutionStatus? resolutionStatus,
    AttachmentConfidence? confidence,
    String? transcribedText,
    String? visionDescription,
  }) {
    return IncomingAttachment(
      type: type ?? this.type,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      observedAt: observedAt ?? this.observedAt,
      source: source ?? this.source,
      durationMs: durationMs ?? this.durationMs,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      confidence: confidence ?? this.confidence,
      transcribedText: transcribedText ?? this.transcribedText,
      visionDescription: visionDescription ?? this.visionDescription,
    );
  }
}
