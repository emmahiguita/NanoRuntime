// inbound_deduplicator.dart
//
// QUÉ HACE:
// Filtra y descarta ráfagas de eventos duplicados provenientes de notificaciones
// o accesibilidad en mensajería (WhatsApp, Telegram, SMS).
//
// CÓMO FUNCIONA:
// - Prefiere el eventId estable de WhatsApp; el texto sólo es fallback legacy.
// - Almacena las huellas recientes con su marca de tiempo en una caché LRU acotada.
// - El mismo eventId se suprime durante el umbral (por defecto 8s); sin ID sólo
//   se usa la huella legacy de texto y remitente.
//
// POR QUÉ:
// Android NotificationListenerService y AccessibilityService disparan ráfagas
// redundantes por la misma notificación al cambiar el estado visual o abrir la app.
// Previene carreras, dobles respuestas, consumo de batería y procesos zombi.

library;

import '../business/fact_selector.dart' show normalizeText;

final class InboundDeduplicator {
  final Duration window;
  final int maxEntries;
  final Map<String, int> _recentFingerprints = {};

  InboundDeduplicator({
    this.window = const Duration(seconds: 8),
    this.maxEntries = 128,
  });

  /// Evalúa identidad de evento para no confundir mensajes legítimos repetidos.
  /// [senderKey] sólo participa en el fallback legacy sin [eventId].
  /// Si no lo es, registra la huella y retorna `false`.
  bool isDuplicate(
    String conversationId,
    String text, {
    String? senderKey,
    String? eventId,
  }) {
    final norm = normalizeText(text).trim();
    if (norm.isEmpty) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final senderSuffix = (senderKey != null && senderKey.trim().isNotEmpty)
        ? ':${senderKey.trim()}'
        : '';
    final stableEventId = eventId?.trim() ?? '';
    final fingerprint = stableEventId.isNotEmpty
        ? '$conversationId:event:$stableEventId'
        : '$conversationId$senderSuffix:${norm.hashCode}';

    // Limpieza oportunista si la caché supera el límite
    if (_recentFingerprints.length > maxEntries) {
      _purgeExpired(now);
      if (_recentFingerprints.length > maxEntries) {
        _recentFingerprints.remove(_recentFingerprints.keys.first);
      }
    }

    final lastSeen = _recentFingerprints[fingerprint];
    if (lastSeen != null && (now - lastSeen) < window.inMilliseconds) {
      return true;
    }

    _recentFingerprints[fingerprint] = now;
    return false;
  }

  void _purgeExpired(int nowMs) {
    final threshold = nowMs - window.inMilliseconds;
    _recentFingerprints.removeWhere((_, timestamp) => timestamp < threshold);
  }

  /// Limpia manualmente todas las entradas registradas.
  void clear() {
    _recentFingerprints.clear();
  }
}
