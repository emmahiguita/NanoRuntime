// whatsapp_media_locator.dart
//
// QUÉ HACE:
// Localizador de archivos multimedia reales (.opus, .jpg, .mp4) de WhatsApp
// en el almacenamiento del dispositivo y la caché interna.
//
// CÓMO FUNCIONA:
// - Escanea en segundo plano con Isolate.run sin bloquear el hilo de interfaz.
// - Aplica correlación temporal fidedigna para identificar archivos recientes.
// - Asigna niveles de confianza según proximidad y colisión de marcas de tiempo.
//
// POR QUÉ:
// Restablece la detección de audios, notas de voz, fotos y videos para visualización
// y transcripción dentro del chat, manteniendo la regla estricta de < 200 líneas.

library;

import 'dart:io';
import 'dart:isolate';
import '../../domain/incoming_attachment.dart';

abstract final class WhatsAppMediaLocator {
  static const List<String> possibleImageDirs = [
    '/data/user/0/dev.nanoai.mobile/cache/nano_notif_media',
    '/data/data/dev.nanoai.mobile/cache/nano_notif_media',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Private',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images',
    '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
  ];

  static const List<String> possibleVideoDirs = [
    '/data/user/0/dev.nanoai.mobile/cache/nano_notif_media',
    '/data/data/dev.nanoai.mobile/cache/nano_notif_media',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Private',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video',
  ];

  static const List<String> possibleVoiceDirs = [
    '/data/user/0/dev.nanoai.mobile/cache/nano_notif_media',
    '/data/data/dev.nanoai.mobile/cache/nano_notif_media',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Voice Notes',
  ];

  /// Localiza una nota de voz con evaluación de confianza temporal.
  static Future<IncomingAttachment> locateVoiceNote({
    int? referenceTimestampMs,
  }) async {
    final refTime = referenceTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await Isolate.run(
        () => _scanAndCorrelate(
          dirs: possibleVoiceDirs,
          validExtensions: const {'.opus', '.ogg', '.m4a', '.mp3', '.aac'},
          referenceMs: refTime,
          recursive: true,
        ),
      );
      return IncomingAttachment(
        type: AttachmentType.voice,
        localPath: res.path,
        mimeType: 'audio/opus',
        observedAt: refTime,
        resolutionStatus: res.path != null
            ? AttachmentResolutionStatus.resolved
            : (res.confidence == AttachmentConfidence.ambiguous
                ? AttachmentResolutionStatus.ambiguous
                : AttachmentResolutionStatus.notFound),
        confidence: res.confidence,
      );
    } catch (_) {
      return IncomingAttachment(
        type: AttachmentType.voice,
        observedAt: refTime,
        resolutionStatus: AttachmentResolutionStatus.failed,
        confidence: AttachmentConfidence.notFound,
      );
    }
  }

  /// Localiza una imagen de WhatsApp con evaluación de confianza temporal.
  static Future<IncomingAttachment> locateImage({
    int? referenceTimestampMs,
  }) async {
    final refTime = referenceTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await Isolate.run(
        () => _scanAndCorrelate(
          dirs: possibleImageDirs,
          validExtensions: const {'.jpg', '.jpeg', '.png', '.webp'},
          referenceMs: refTime,
          recursive: false,
        ),
      );
      return IncomingAttachment(
        type: AttachmentType.image,
        localPath: res.path,
        mimeType: 'image/jpeg',
        observedAt: refTime,
        resolutionStatus: res.path != null
            ? AttachmentResolutionStatus.resolved
            : (res.confidence == AttachmentConfidence.ambiguous
                ? AttachmentResolutionStatus.ambiguous
                : AttachmentResolutionStatus.notFound),
        confidence: res.confidence,
      );
    } catch (_) {
      return IncomingAttachment(
        type: AttachmentType.image,
        observedAt: refTime,
        resolutionStatus: AttachmentResolutionStatus.failed,
        confidence: AttachmentConfidence.notFound,
      );
    }
  }

  /// Localiza un video de WhatsApp con evaluación de confianza temporal.
  static Future<IncomingAttachment> locateVideo({
    int? referenceTimestampMs,
  }) async {
    final refTime = referenceTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await Isolate.run(
        () => _scanAndCorrelate(
          dirs: possibleVideoDirs,
          validExtensions: const {'.mp4', '.mov', '.3gp', '.mkv'},
          referenceMs: refTime,
          recursive: false,
        ),
      );
      return IncomingAttachment(
        type: AttachmentType.video,
        localPath: res.path,
        mimeType: 'video/mp4',
        observedAt: refTime,
        resolutionStatus: res.path != null
            ? AttachmentResolutionStatus.resolved
            : (res.confidence == AttachmentConfidence.ambiguous
                ? AttachmentResolutionStatus.ambiguous
                : AttachmentResolutionStatus.notFound),
        confidence: res.confidence,
      );
    } catch (_) {
      return IncomingAttachment(
        type: AttachmentType.video,
        observedAt: refTime,
        resolutionStatus: AttachmentResolutionStatus.failed,
        confidence: AttachmentConfidence.notFound,
      );
    }
  }

  static ({String? path, AttachmentConfidence confidence}) _scanAndCorrelate({
    required List<String> dirs,
    required Set<String> validExtensions,
    required int referenceMs,
    required bool recursive,
  }) {
    final candidates = <({String path, int modMs})>[];
    for (final dirPath in dirs) {
      final d = Directory(dirPath);
      if (!d.existsSync()) continue;
      try {
        final entries = d.listSync(recursive: recursive, followLinks: false);
        for (final e in entries) {
          if (e is! File) continue;
          final p = e.path.toLowerCase();
          if (p.contains('/sent/')) continue;
          if (validExtensions.any((ext) => p.endsWith(ext))) {
            try {
              final mod = e.statSync().modified.millisecondsSinceEpoch;
              candidates.add((path: e.path, modMs: mod));
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    if (candidates.isEmpty) {
      return (path: null, confidence: AttachmentConfidence.notFound);
    }

    const windowMs = 60 * 1000;
    final inWindow = candidates
        .where((c) => (c.modMs - referenceMs).abs() <= windowMs)
        .toList();

    if (inWindow.isEmpty) {
      candidates.sort(
        (a, b) => (a.modMs - referenceMs).abs().compareTo((b.modMs - referenceMs).abs()),
      );
      final best = candidates.first;
      final diff = (best.modMs - referenceMs).abs();
      if (diff <= 120 * 1000) {
        return (
          path: best.path,
          confidence: AttachmentConfidence.resolvedHighConfidence,
        );
      }
      return (path: null, confidence: AttachmentConfidence.notFound);
    }

    inWindow.sort(
      (a, b) => (a.modMs - referenceMs).abs().compareTo((b.modMs - referenceMs).abs()),
    );
    if (inWindow.length > 1) {
      final diff1 = (inWindow[0].modMs - referenceMs).abs();
      final diff2 = (inWindow[1].modMs - referenceMs).abs();
      if ((diff1 - diff2).abs() < 2500 && inWindow[0].path != inWindow[1].path) {
        return (path: null, confidence: AttachmentConfidence.ambiguous);
      }
    }

    return (
      path: inWindow.first.path,
      confidence: AttachmentConfidence.resolvedHighConfidence,
    );
  }
}
