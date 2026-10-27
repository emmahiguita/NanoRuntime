import 'incoming_attachment.dart';

/// QUÉ: conserva únicamente archivos vinculados al evento por Android.
/// CÓMO: traduce campos del canal; nunca convierte texto del contacto en rutas.
/// POR QUÉ: una etiqueta «[PDF: /ruta]» escrita en el chat no autoriza leer disco.
abstract final class NotificationAttachmentCodec {
  static List<IncomingAttachment> decode(Map<dynamic, dynamic> raw) => [
    for (final entry in const {
      'audioPath': (AttachmentType.voice, 'audio/opus'),
      'imagePath': (AttachmentType.image, 'image/jpeg'),
      'videoPath': (AttachmentType.video, 'video/mp4'),
      'pdfPath': (AttachmentType.document, 'application/pdf'),
    }.entries)
      if (raw[entry.key] is String &&
          (raw[entry.key] as String).trim().isNotEmpty)
        IncomingAttachment(
          type: entry.value.$1,
          localPath: (raw[entry.key] as String).trim(),
          mimeType:
              '${raw['${entry.key}MimeType'] ?? raw['mediaMimeType'] ?? entry.value.$2}',
          observedAt: (raw['messageTimestamp'] as num?)?.toInt() ?? 0,
          source: '${raw['package'] ?? 'android_message_uri'}',
          resolutionStatus: AttachmentResolutionStatus.resolved,
          confidence: AttachmentConfidence.resolvedExact,
        ),
  ];

  /// Los metadatos canónicos permiten releer el adjunto tras reiniciar la app.
  static Map<String, Object?> metadata(IncomingAttachment attachment) => {
    'type': attachment.type.name,
    'path': attachment.localPath,
    'mime': attachment.mimeType,
    'at': attachment.observedAt,
    'source': attachment.source,
  };

  static List<IncomingAttachment> fromMetadata(Object? value) => value is! List
      ? []
      : [
          for (final row in value.whereType<Map>())
            if (row['path'] is String &&
                AttachmentType.values.any((t) => t.name == row['type']))
              IncomingAttachment(
                type: AttachmentType.values.firstWhere(
                  (t) => t.name == row['type'],
                ),
                localPath: row['path'] as String,
                mimeType: '${row['mime'] ?? ''}',
                observedAt: (row['at'] as num?)?.toInt() ?? 0,
                source: '${row['source'] ?? ''}',
                resolutionStatus: AttachmentResolutionStatus.resolved,
                confidence: AttachmentConfidence.resolvedExact,
              ),
        ];
}
