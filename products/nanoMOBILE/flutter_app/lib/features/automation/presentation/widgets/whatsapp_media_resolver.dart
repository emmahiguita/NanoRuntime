import '../../data/media/whatsapp_media_locator.dart';
import '../../domain/incoming_attachment.dart';

/// Caché acotada del localizador real: no convierte una búsqueda fallida en ausencia permanente.
abstract final class WhatsAppMediaResolver {
  static final _cache = <String, ({String? path, DateTime at})>{};
  static final _inFlight = <String, Future<String?>>{};

  // Una reconstrucción comparte la lectura en curso; no abre otro Isolate para el mismo medio.
  // Los fallos caducan a los 2s para permitir descargar el archivo y volver a abrirlo.
  static Future<String?> _find(
    String kind,
    int? timestamp,
    Future<IncomingAttachment> Function() load,
  ) async {
    if (timestamp == null || timestamp <= 0) return null;
    final key = '$kind:$timestamp';
    final cached = _cache[key];
    final ttl = Duration(seconds: cached?.path == null ? 2 : 180);
    if (cached != null && DateTime.now().difference(cached.at) < ttl) {
      return cached.path;
    }
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = () async {
      final attachment = await load();
      _cache.remove(key);
      _cache[key] = (path: attachment.localPath, at: DateTime.now());
      if (_cache.length > 256) _cache.remove(_cache.keys.first);
      return attachment.localPath;
    }();
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  // Cada tipo conserva las mismas comprobaciones de confianza del localizador.
  static Future<String?> findRecentWhatsAppImage({int? referenceTimestampMs}) =>
      _find(
        'image',
        referenceTimestampMs,
        () => WhatsAppMediaLocator.locateImage(
          referenceTimestampMs: referenceTimestampMs,
        ),
      );
  static Future<String?> findRecentWhatsAppVideo({int? referenceTimestampMs}) =>
      _find(
        'video',
        referenceTimestampMs,
        () => WhatsAppMediaLocator.locateVideo(
          referenceTimestampMs: referenceTimestampMs,
        ),
      );
  static Future<String?> findRecentWhatsAppVoiceNote({
    int? referenceTimestampMs,
  }) => _find(
    'voice',
    referenceTimestampMs,
    () => WhatsAppMediaLocator.locateVoiceNote(
      referenceTimestampMs: referenceTimestampMs,
    ),
  );

  // No cancela tareas de otros consumidores; solo invalida resultados ya almacenados.
  static void invalidateCache() => _cache.clear();
}
