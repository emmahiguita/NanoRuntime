// conversation_media_enricher.dart
//
// QUÉ HACE:
// Conecta medios reales de WhatsApp (audios .opus y fotos) con el pipeline conversacional
// del Agente Personal, desacoplado de widgets UI y aplicando "MEDIA DETECTADA ≠ MEDIA COMPRENDIDA".
//
// CÓMO FUNCIONA:
// - Localiza adjuntos mediante WhatsAppMediaLocator con evaluación estricta de confianza.
// - Transcribe notas de voz locales con WhisperSttService / VoiceNoteTranscriber.
// - Enriquece semánticamente la notificación antes del LLM con el texto realmente dicho.
// - Si el medio no pudo comprenderse o hay ambigüedad, activa guardas para evitar respuestas a ciegas.
//
// POR QUÉ:
// Erradica respuestas desorientadas ante "Mensaje de voz" o "Foto" cumpliendo Clean Architecture.

library;

import 'package:flutter/foundation.dart' show debugPrint;
import '../../data/media/whatsapp_media_locator.dart';
import '../../domain/incoming_attachment.dart';
import '../../presentation/widgets/parsed_media_message.dart';
import '../../presentation/widgets/voice_note_transcriber.dart';
import '../notifications/notification_object.dart';

final class MediaEnrichmentResult {
  final NotificationObject notification;
  final bool audioUnprocessed;
  final bool photoUnprocessed;
  final bool photoDetected;
  final String? mediaPath;
  final String? transcribedText;
  final IncomingAttachment? attachment;

  const MediaEnrichmentResult({
    required this.notification,
    this.audioUnprocessed = false,
    this.photoUnprocessed = false,
    this.photoDetected = false,
    this.mediaPath,
    this.transcribedText,
    this.attachment,
  });
}

abstract final class ConversationMediaEnricher {
  /// Enriquece la notificación localizando medios reales y transcribiendo notas de voz.
  static Future<MediaEnrichmentResult> enrich(NotificationObject notification) async {
    final rawText = notification.messageText.isNotEmpty
        ? notification.messageText
        : notification.text;
    if (rawText.trim().isEmpty) {
      return MediaEnrichmentResult(notification: notification);
    }

    final parsed = ParsedMediaMessage.parse(rawText);
    final refTime = notification.messageTimestamp > 0
        ? notification.messageTimestamp
        : notification.postTime;

    // 1. Detección de Nota de Voz / Audio de WhatsApp
    if (parsed.isAudioNotification || parsed.audios.isNotEmpty) {
      final attachment = await WhatsAppMediaLocator.locateVoiceNote(
        referenceTimestampMs: refTime > 0 ? refTime : null,
      );

      if (attachment.isResolved && attachment.localPath != null) {
        final audioPath = attachment.localPath!;
        debugPrint('[media-enricher] Audio correlacionado (${attachment.confidence.name}): $audioPath');
        try {
          final transcript = await VoiceNoteTranscriber.transcribe(
            audioPathOrUrl: audioPath,
            force: true,
          );

          final clean = transcript.trim();
          final isErrorOrAdvice = clean.isEmpty ||
              clean.contains('no encontrado') ||
              clean.contains('vacío (0 bytes)') ||
              clean.contains('descarga Whisper') ||
              clean.startsWith('Audio OPUS');

          if (!isErrorOrAdvice) {
            debugPrint('[media-enricher] Transcripción exitosa: "$clean"');
            final enrichedAttach = attachment.copyWith(
              resolutionStatus: AttachmentResolutionStatus.processed,
              transcribedText: clean,
            );
            final semanticText = 'Nota de voz transcrita: "$clean"';
            final enrichedNotif = notification.withText(
              semanticText,
              attachments: [enrichedAttach],
            );
            return MediaEnrichmentResult(
              notification: enrichedNotif,
              mediaPath: audioPath,
              transcribedText: clean,
              attachment: enrichedAttach,
            );
          }
        } catch (e) {
          debugPrint('[media-enricher] Error transcribiendo audio: $e');
        }
      }

      // Audio detectado pero no comprendido (ambigüedad, no encontrado o STT no disponible)
      debugPrint('[media-enricher] Audio sin transcripción (confianza: ${attachment.confidence.name})');
      return MediaEnrichmentResult(
        notification: notification.withText(
          notification.text,
          attachments: [attachment.copyWith(resolutionStatus: AttachmentResolutionStatus.failed)],
        ),
        audioUnprocessed: true,
        mediaPath: attachment.localPath,
        attachment: attachment,
      );
    }

    // 2. Detección de Foto / Imagen de WhatsApp
    if (parsed.isPhotoNotification || parsed.images.isNotEmpty) {
      final attachment = await WhatsAppMediaLocator.locateImage(
        referenceTimestampMs: refTime > 0 ? refTime : null,
      );

      debugPrint('[media-enricher] Foto detectada (${attachment.confidence.name}): ${attachment.localPath ?? "sin ruta"}');
      // Ciclo 6: Sin runtime visual funcional disponible, mediaResolved = true, visionAnalyzed = false.
      // Se prohíben respuestas autónomas sobre el contenido visual no comprendido.
      return MediaEnrichmentResult(
        notification: notification.withText(
          notification.text,
          attachments: [attachment],
        ),
        photoDetected: true,
        photoUnprocessed: true,
        mediaPath: attachment.localPath,
        attachment: attachment,
      );
    }

    // 3. Mensaje textual estándar
    return MediaEnrichmentResult(notification: notification);
  }
}
