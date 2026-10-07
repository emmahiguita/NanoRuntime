// whatsapp_media_resolver.dart
//
// QUÉ HACE:
// Adaptador de presentación que expone la localización de medios de WhatsApp
// para widgets de interfaz de usuario sin bloquear el frame rate.
//
// CÓMO FUNCIONA:
// Delega al servicio compartido WhatsAppMediaLocator en la capa de datos/infraestructura.
//
// POR QUÉ:
// Evita el acoplamiento invertido (Personal Agent -> widgets) y garantiza que la UI
// y el pipeline conversacional compartan exactamente la misma fuente de verdad.

library;

import '../../data/media/whatsapp_media_locator.dart';

abstract final class WhatsAppMediaResolver {
  static final _resolvedCache = <String, String?>{};

  /// Busca la imagen de WhatsApp correspondiente al timestamp usando el localizador compartido.
  static Future<String?> findRecentWhatsAppImage({
    int? referenceTimestampMs,
  }) async {
    final cacheKey = 'img_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    final attachment = await WhatsAppMediaLocator.locateImage(
      referenceTimestampMs: referenceTimestampMs,
    );
    _resolvedCache[cacheKey] = attachment.localPath;
    return attachment.localPath;
  }

  /// Busca el video de WhatsApp correspondiente al timestamp usando el localizador compartido.
  static Future<String?> findRecentWhatsAppVideo({
    int? referenceTimestampMs,
  }) async {
    final cacheKey = 'vid_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    final attachment = await WhatsAppMediaLocator.locateVideo(
      referenceTimestampMs: referenceTimestampMs,
    );
    _resolvedCache[cacheKey] = attachment.localPath;
    return attachment.localPath;
  }

  /// Busca la nota de voz correspondiente al timestamp usando el localizador compartido.
  static Future<String?> findRecentWhatsAppVoiceNote({
    int? referenceTimestampMs,
  }) async {
    final cacheKey = 'voice_${referenceTimestampMs ?? 0}';
    if (_resolvedCache.containsKey(cacheKey)) return _resolvedCache[cacheKey];

    final attachment = await WhatsAppMediaLocator.locateVoiceNote(
      referenceTimestampMs: referenceTimestampMs,
    );
    _resolvedCache[cacheKey] = attachment.localPath;
    return attachment.localPath;
  }

  /// Invalida la caché de resolución si se requiere forzar re-escaneo.
  static void invalidateCache() {
    _resolvedCache.clear();
  }
}
