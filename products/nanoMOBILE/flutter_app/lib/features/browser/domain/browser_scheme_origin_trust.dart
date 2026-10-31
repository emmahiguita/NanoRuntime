/// QUÉ HACE:
/// Valida la relación de confianza entre esquemas de aplicaciones externas
/// (whatsapp, tg, snssdk/tiktok, instagram, etc.), proveedores OAuth federados
/// y el origen web emisor.
///
/// CÓMO FUNCIONA:
/// Comprueba listas blancas de hosts OAuth (incluyendo dominios regionales con
/// expresión regular anclada) y verifica que un deep link hacia una app externa
/// provenga de su propio dominio oficial antes de permitir su apertura automática.
///
/// POR QUÉ:
/// Extrae la responsabilidad de validación de orígenes de `BrowserNavigationPolicy`
/// para mantener ambos archivos por debajo de 200 líneas y prevenir secuestros de
/// intent o popups no autorizados.
class BrowserSchemeOriginTrust {
  const BrowserSchemeOriginTrust._();

  static const Set<String> tikTokSchemes = {
    'snssdk1340',
    'snssdk1180',
    'snssdk1233',
    'tiktok',
  };

  /// Hosts de proveedores de identidad federada (OAuth) que requieren `window.open`.
  static const Set<String> _oAuthProviderHosts = {
    'accounts.google.com',
    'appleid.apple.com',
    'github.com',
    'login.microsoftonline.com',
  };

  /// Variantes regionales bajo dominios raíz oficiales (ancla `$` evita sufijos falsos).
  static final RegExp _oAuthRegionalHostPattern = RegExp(
    r'^(accounts\.google\.[a-z]{2,3}(\.[a-z]{2,3})?'
    r'|login\.microsoftonline\.[a-z]{2,3})$',
  );

  /// Determina si un esquema corresponde a TikTok (ej. snssdk1340).
  static bool isTikTokScheme(String scheme) {
    final s = scheme.trim().toLowerCase();
    return tikTokSchemes.contains(s) || s.startsWith('snssdk');
  }

  /// Determina si el host pertenece a un proveedor OAuth federado permitido.
  static bool isOAuthProviderHost(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return false;
    for (final p in _oAuthProviderHosts) {
      if (h == p || h.endsWith('.$p')) return true;
    }
    return _oAuthRegionalHostPattern.hasMatch(h);
  }

  /// Determina si el origen web corresponde a TikTok.
  static bool isTikTokOrigin(String origin) {
    final clean = origin.trim().toLowerCase();
    try {
      final uri = Uri.tryParse(clean);
      final host = (uri != null && uri.host.isNotEmpty) ? uri.host : clean;
      return host == 'tiktok.com' ||
          host.endsWith('.tiktok.com') ||
          clean.contains('tiktok.com');
    } catch (_) {
      return clean.contains('tiktok.com');
    }
  }

  /// Verifica si el esquema solicitado tiene relación legítima con el origen web emisor.
  static bool isTrustedSchemeForOrigin({
    required String scheme,
    required String origin,
  }) {
    final s = scheme.trim().toLowerCase();
    final o = origin.trim().toLowerCase();

    if (isTikTokScheme(s)) return isTikTokOrigin(o);
    if (s == 'whatsapp') {
      return o.contains('whatsapp.com') || o.contains('wa.me');
    }
    if (s == 'tg' || s == 'telegram') {
      return o.contains('telegram.org') || o.contains('t.me');
    }
    if (s == 'instagram') return o.contains('instagram.com');
    if (s == 'twitter' || s == 'x') {
      return o.contains('twitter.com') || o.contains('x.com');
    }
    if (s == 'youtube' || s == 'vnd.youtube') {
      return o.contains('youtube.com') || o.contains('youtu.be');
    }
    return false;
  }
}
