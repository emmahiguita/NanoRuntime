// tiktok_web_policy.dart
//
// QUÉ HACE: decide el destino de cada navegación relacionada con TikTok Web
// (https, deep links snssdk/tiktok/musically e intent:// con fallback web).
//
// CÓMO FUNCIONA: clasifica el esquema y aplica el modo configurado de
// comportamiento para apps externas. `STAY_IN_WEB` (default) cancela en
// silencio y mantiene al usuario dentro del WebView; `ASK` pregunta solo con
// gesto del usuario; `ALLOW_EXPLICIT` lanza la app solo con gesto.
//
// POR QUÉ: TikTok Web intenta saltar continuamente a la app nativa. Estas
// reglas viven aquí, aisladas del guard, para no dispersar la política por el
// navegador (SRP) y poder testearlas sin WebView ni UI.

/// Comportamiento ante deep links de aplicaciones externas.
enum ExternalAppBehavior {
  stayInWeb('STAY_IN_WEB', 'Permanecer en web'),
  ask('ASK', 'Preguntar'),
  allowExplicit('ALLOW_EXPLICIT', 'Permitir app externa');

  const ExternalAppBehavior(this.id, this.label);

  final String id;
  final String label;

  static ExternalAppBehavior fromId(String? id) => values.firstWhere(
    (b) => b.id == id,
    orElse: () => ExternalAppBehavior.stayInWeb,
  );
}

/// Decisión atómica para una navegación hacia app externa desde TikTok Web.
enum TikTokNavigationDecision {
  /// Navegación web normal.
  allowWeb,

  /// Cancelar en silencio y quedarse en la página actual (sin modales).
  stayInWeb,

  /// Preguntar al usuario (solo modos ASK con gesto explícito).
  askUser,

  /// El usuario pidió abrir la app y la configuración lo permite.
  openExternalExplicitly,

  /// Amenaza real (red privada, esquema peligroso): bloquear.
  blockSecurityThreat,
}

class TikTokWebPolicy {
  const TikTokWebPolicy._();

  /// Origen web legítimo de TikTok (tiktok.com y subdominios).
  static bool isTikTokOrigin(Uri? origin) {
    if (origin == null) return false;
    final host = origin.host.toLowerCase();
    return host == 'tiktok.com' ||
        host == 'www.tiktok.com' ||
        host.endsWith('.tiktok.com');
  }

  /// Deep link de la aplicación TikTok (snssdk1340, tiktok://, musically://).
  static bool isTikTokAppScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme.startsWith('snssdk') ||
        scheme == 'tiktok' ||
        scheme == 'musically';
  }

  /// `intent://` dirigido a TikTok (paquete o esquema snssdk en el fragmento).
  static bool isTikTokIntent(Uri uri) {
    if (uri.scheme.toLowerCase() != 'intent') return false;
    final probe = uri.toString().toLowerCase();
    return probe.contains('tiktok') ||
        probe.contains('musically') ||
        probe.contains('snssdk') ||
        probe.contains('zhiliaoapp');
  }

  /// Extrae `S.browser_fallback_url=` de un intent:// como URL web segura.
  ///
  /// Android define ese parámetro como el destino web alternativo cuando la
  /// app nativa no está instalada; usarlo evita el salto a la app manteniendo
  /// la navegación continua.
  static Uri? extractIntentWebFallback(Uri uri) {
    if (uri.scheme.toLowerCase() != 'intent') return null;
    for (final part in uri.fragment.split(';')) {
      if (!part.startsWith('S.browser_fallback_url=')) continue;
      final raw = part.substring('S.browser_fallback_url='.length);
      final fallback = Uri.tryParse(Uri.decodeFull(raw));
      if (fallback == null) continue;
      final scheme = fallback.scheme.toLowerCase();
      if ((scheme == 'http' || scheme == 'https') &&
          fallback.host.isNotEmpty) {
        return fallback;
      }
    }
    return null;
  }

  /// Decide el manejo de un deep link TikTok según gesto y configuración.
  static TikTokNavigationDecision decideAppScheme({
    required Uri uri,
    required bool hasGesture,
    required ExternalAppBehavior behavior,
  }) {
    if (!isTikTokAppScheme(uri)) {
      return TikTokNavigationDecision.stayInWeb;
    }
    switch (behavior) {
      case ExternalAppBehavior.stayInWeb:
        // Default del producto: jamás abrir la app ni mostrar diálogos.
        return TikTokNavigationDecision.stayInWeb;
      case ExternalAppBehavior.ask:
        return hasGesture
            ? TikTokNavigationDecision.askUser
            : TikTokNavigationDecision.stayInWeb;
      case ExternalAppBehavior.allowExplicit:
        return hasGesture
            ? TikTokNavigationDecision.openExternalExplicitly
            : TikTokNavigationDecision.stayInWeb;
    }
  }
}
