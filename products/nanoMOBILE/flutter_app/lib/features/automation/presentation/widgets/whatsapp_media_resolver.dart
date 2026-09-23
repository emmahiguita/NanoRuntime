// whatsapp_media_resolver.dart
//
// QUÉ HACE:
// Localiza de forma real y factual las fotos, videos y notas de voz almacenadas por WhatsApp
// en el almacenamiento del dispositivo Android cuando se reciben notificaciones.
//
// CÓMO FUNCIONA:
// - Escanea las rutas oficiales de WhatsApp y WhatsApp Business en Android/media.
// - Si se proporciona un timestamp de referencia, busca el archivo más cercano en tiempo.
// - Si no hay timestamp, selecciona el archivo más reciente ordenado por fecha de modificación.
//
// POR QUÉ:
// Resuelve el problema visual donde fotos y videos aparecían como texto plano ("📷 Envió una foto."),
// garantizando visualización real sin inventar datos (SOLID - Clean Architecture, < 200 líneas).

library;

import 'dart:io';

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

  /// Busca la imagen más reciente o más cercana al timestamp de WhatsApp.
  static Future<String?> findRecentWhatsAppImage({int? referenceTimestampMs}) async {
    final cacheKey = 'img_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    try {
      final file = _findClosestFile(
        dirs: _possibleImageDirs,
        validExtensions: {'.jpg', '.jpeg', '.png', '.webp'},
        referenceTimestampMs: referenceTimestampMs,
        recursive: false,
      );
      final result = file?.path;
      _resolvedCache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Busca el video más reciente o más cercano al timestamp de WhatsApp.
  static Future<String?> findRecentWhatsAppVideo({int? referenceTimestampMs}) async {
    final cacheKey = 'vid_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    try {
      final file = _findClosestFile(
        dirs: _possibleVideoDirs,
        validExtensions: {'.mp4', '.mov', '.3gp', '.mkv'},
        referenceTimestampMs: referenceTimestampMs,
        recursive: false,
      );
      final result = file?.path;
      _resolvedCache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Busca la nota de voz más reciente o más cercana al timestamp de WhatsApp.
  static Future<String?> findRecentWhatsAppVoiceNote({int? referenceTimestampMs}) async {
    final cacheKey = 'voice_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    try {
      final file = _findClosestFile(
        dirs: _possibleVoiceDirs,
        validExtensions: {'.opus', '.ogg', '.m4a', '.mp3', '.aac'},
        referenceTimestampMs: referenceTimestampMs,
        recursive: true,
      );
      final result = file?.path;
      _resolvedCache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  static File? _findClosestFile({
    required List<String> dirs,
    required Set<String> validExtensions,
    int? referenceTimestampMs,
    required bool recursive,
  }) {
    final candidates = <File>[];

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync(recursive: recursive, followLinks: false);
        for (final entity in entities) {
          if (entity is! File) continue;
          final p = entity.path.toLowerCase();
          // Ignorar archivos enviados por el propio usuario (carpeta Sent)
          if (p.contains('/sent/')) continue;
          if (validExtensions.any((ext) => p.endsWith(ext))) {
            candidates.add(entity);
          }
        }
      } catch (_) {}
    }

    if (candidates.isEmpty) return null;

    // Si hay timestamp de referencia, encontrar el más cercano (hasta 24h de margen)
    if (referenceTimestampMs != null && referenceTimestampMs > 0) {
      File? bestMatch;
      int bestDiff = 1000 * 60 * 60 * 24; // 24 horas

      for (final candidate in candidates) {
        try {
          final mod = candidate.statSync().modified.millisecondsSinceEpoch;
          final diff = (referenceTimestampMs - mod).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestMatch = candidate;
          }
        } catch (_) {}
      }
      if (bestMatch != null) return bestMatch;
    }

    // Fallback: ordenar por fecha de modificación descendente (el más reciente)
    candidates.sort((a, b) {
      final aMod = a.statSync().modified.millisecondsSinceEpoch;
      final bMod = b.statSync().modified.millisecondsSinceEpoch;
      return bMod.compareTo(aMod);
    });

    return candidates.first;
  }
}
