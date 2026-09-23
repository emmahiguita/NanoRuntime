// whatsapp_media_resolver.dart
//
// QUÉ HACE:
// Localiza de forma real y factual las fotos, videos y notas de voz almacenadas
// por WhatsApp en el almacenamiento del dispositivo Android sin bloquear el hilo
// de interfaz de usuario.
//
// CÓMO FUNCIONA:
// - Escanea en segundo plano mediante `Isolate.run` las rutas oficiales de WhatsApp.
// - Lee los metadatos de fecha en una sola pasada O(N), evitando lecturas repetidas a disco.
// - Si se provee un timestamp de referencia, selecciona el archivo más cercano en tiempo.
// - Si no hay timestamp, selecciona el más reciente según la fecha de modificación.
//
// POR QUÉ:
// Resuelve el cuello de botella (AUT-P2-12) donde el escaneo recursivo y las múltiples
// llamadas síncronas a stat() congelaban los frames de la UI. Cumple SOLID y límite < 200 líneas.

library;

import 'dart:io';
import 'dart:isolate';

/// Resuelve medios reales de WhatsApp guardados en el almacenamiento del dispositivo.
abstract final class WhatsAppMediaResolver {
  static final _resolvedCache = <String, String?>{};

  static const List<String> _possibleImageDirs = [
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Private',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images',
    '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
  ];

  static const List<String> _possibleVideoDirs = [
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Private',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video',
  ];

  static const List<String> _possibleVoiceDirs = [
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Voice Notes',
  ];

  /// Busca la imagen más reciente o más cercana al timestamp de WhatsApp en un isolate secundario.
  static Future<String?> findRecentWhatsAppImage({int? referenceTimestampMs}) async {
    final cacheKey = 'img_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    try {
      final path = await Isolate.run(() => _findClosestFilePath(
        dirs: _possibleImageDirs,
        validExtensions: const {'.jpg', '.jpeg', '.png', '.webp'},
        referenceTimestampMs: referenceTimestampMs,
        recursive: false,
      ));
      _resolvedCache[cacheKey] = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Busca el video más reciente o más cercano al timestamp de WhatsApp en un isolate secundario.
  static Future<String?> findRecentWhatsAppVideo({int? referenceTimestampMs}) async {
    final cacheKey = 'vid_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    try {
      final path = await Isolate.run(() => _findClosestFilePath(
        dirs: _possibleVideoDirs,
        validExtensions: const {'.mp4', '.mov', '.3gp', '.mkv'},
        referenceTimestampMs: referenceTimestampMs,
        recursive: false,
      ));
      _resolvedCache[cacheKey] = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Busca la nota de voz más reciente o más cercana al timestamp en un isolate secundario.
  static Future<String?> findRecentWhatsAppVoiceNote({int? referenceTimestampMs}) async {
    final cacheKey = 'voice_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    try {
      final path = await Isolate.run(() => _findClosestFilePath(
        dirs: _possibleVoiceDirs,
        validExtensions: const {'.opus', '.ogg', '.m4a', '.mp3', '.aac'},
        referenceTimestampMs: referenceTimestampMs,
        recursive: true,
      ));
      _resolvedCache[cacheKey] = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Escanea directorios en el isolate de fondo recolectando metadatos en una única pasada O(N).
  static String? _findClosestFilePath({
    required List<String> dirs,
    required Set<String> validExtensions,
    int? referenceTimestampMs,
    required bool recursive,
  }) {
    final candidates = <({String path, int modifiedMs})>[];

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync(recursive: recursive, followLinks: false);
        for (final entity in entities) {
          if (entity is! File) continue;
          final p = entity.path.toLowerCase();
          if (p.contains('/sent/')) continue;
          if (validExtensions.any((ext) => p.endsWith(ext))) {
            try {
              final mod = entity.statSync().modified.millisecondsSinceEpoch;
              candidates.add((path: entity.path, modifiedMs: mod));
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    if (candidates.isEmpty) return null;

    if (referenceTimestampMs != null && referenceTimestampMs > 0) {
      String? bestPath;
      int bestDiff = 1000 * 60 * 60 * 24; // Margen de 24 horas

      for (final candidate in candidates) {
        final diff = (referenceTimestampMs - candidate.modifiedMs).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestPath = candidate.path;
        }
      }
      if (bestPath != null) return bestPath;
    }

    // Ordenamiento puramente en memoria O(N log N) sin llamadas a disco adicionales
    candidates.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    return candidates.first.path;
  }
}
