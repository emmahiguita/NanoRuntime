import 'package:nanoai/features/browser/domain/browser_scheme_origin_trust.dart';

/// Tipo de destino para clasificar solicitudes de navegación antes del firewall.
enum NavigationTargetType {
  web,
  internalWeb,
  externalApp,
  phone,
  email,
  store,
  unsupported,
}

/// QUÉ HACE:
/// Clasifica esquemas de navegación y define políticas de deep links e intenciones externas.
///
/// CÓMO FUNCIONA:
/// Separa esquemas web (http/https), recursos internos legítimos (about/blob/data),
/// handlers de comunicación (tel/mailto/market) y deep links de aplicaciones externas
/// antes de la inspección del firewall de red.
///
/// POR QUÉ:
/// Evita clasificar erróneamente esquemas de aplicaciones externas como amenazas de red local
/// y delega la validación de confianza por origen a `BrowserSchemeOriginTrust` (< 175 líneas).
class BrowserNavigationPolicy {
  const BrowserNavigationPolicy._();

  static const Set<String> _blockedSchemes = {
    'file',
    'content',
    'chrome',
    'javascript',
    'vbscript',
  };

  static const Set<String> _internalWebSchemes = {
    'about',
    'blob',
    'data',
  };

  static const Set<String> _phoneSchemes = {'tel', 'sms'};
  static const Set<String> _emailSchemes = {'mailto'};
  static const Set<String> _storeSchemes = {'market', 'itms-apps'};

  static const Set<String> _knownExternalAppSchemes = {
    'intent',
    'whatsapp',
    'tg',
    'telegram',
    'instagram',
    'twitter',
    'x',
    'youtube',
    'vnd.youtube',
    'fb',
    'facebook',
    'fb-messenger',
    'linkedin',
    'pinterest',
    'snapchat',
    'spotify',
    'discord',
    'slack',
    'zoomus',
    'skype',
    'viber',
    'line',
    'reddit',
  };

  static final RegExp _customSchemePattern = RegExp(r'^[a-z][a-z0-9+.-]*$');

  /// Clasifica una URI según su esquema antes de someterla a validaciones de red.
  static NavigationTargetType classifyUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) return NavigationTargetType.unsupported;
    if (scheme == 'http' || scheme == 'https') return NavigationTargetType.web;
    if (_internalWebSchemes.contains(scheme)) {
      return NavigationTargetType.internalWeb;
    }
    if (_phoneSchemes.contains(scheme)) return NavigationTargetType.phone;
    if (_emailSchemes.contains(scheme)) return NavigationTargetType.email;
    if (_storeSchemes.contains(scheme)) return NavigationTargetType.store;
    if (_blockedSchemes.contains(scheme)) {
      return NavigationTargetType.unsupported;
    }
    if (isExternalAppScheme(scheme)) return NavigationTargetType.externalApp;
    return NavigationTargetType.unsupported;
  }

  /// Determina si un esquema corresponde a TikTok (ej. snssdk1340).
  static bool isTikTokScheme(String scheme) =>
      BrowserSchemeOriginTrust.isTikTokScheme(scheme);

  /// Determina si el host pertenece a un proveedor OAuth federado permitido.
  static bool isOAuthProviderHost(String host) =>
      BrowserSchemeOriginTrust.isOAuthProviderHost(host);

  /// Determina si el origen web corresponde a TikTok.
  static bool isTikTokOrigin(String origin) =>
      BrowserSchemeOriginTrust.isTikTokOrigin(origin);

  /// Verifica si el esquema solicitado tiene relación legítima con el origen web emisor.
  static bool isTrustedSchemeForOrigin({
    required String scheme,
    required String origin,
  }) =>
      BrowserSchemeOriginTrust.isTrustedSchemeForOrigin(
        scheme: scheme,
        origin: origin,
      );

  /// Indica si el esquema corresponde a una aplicación externa conocida o personalizada.
  static bool isExternalAppScheme(String scheme) {
    final s = scheme.trim().toLowerCase();
    if (isTikTokScheme(s)) return true;
    if (_knownExternalAppSchemes.contains(s)) return true;
    return isCustomScheme(s);
  }

  /// Detecta si es un esquema personalizado válido (ej. app://, custom://).
  static bool isCustomScheme(String scheme) {
    final s = scheme.trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s == 'http' || s == 'https') return false;
    if (_internalWebSchemes.contains(s)) return false;
    if (_blockedSchemes.contains(s)) return false;
    if (_phoneSchemes.contains(scheme)) return false;
    if (_emailSchemes.contains(scheme)) return false;
    if (_storeSchemes.contains(scheme)) return false;
    return _customSchemePattern.hasMatch(s);
  }

  /// Extrae el origen (scheme + host + port) sin parámetros de consulta ni tokens sensibles.
  static String extractOrigin(Uri? uri, {Map<String, String>? headers}) {
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        try {
          return uri.origin;
        } catch (_) {
          if (uri.host.isNotEmpty) {
            final port = uri.hasPort ? ':${uri.port}' : '';
            return '${uri.scheme}://${uri.host}$port';
          }
        }
      }
      if (uri.scheme == 'about') return uri.toString();
      if (uri.host.isNotEmpty) return uri.host;
    }

    if (headers != null) {
      final referer = headers['Referer'] ??
          headers['referer'] ??
          headers['Origin'] ??
          headers['origin'];
      if (referer != null && referer.isNotEmpty) {
        final parsed = Uri.tryParse(referer);
        if (parsed != null &&
            parsed.hasScheme &&
            (parsed.scheme == 'http' || parsed.scheme == 'https')) {
          try {
            return parsed.origin;
          } catch (_) {
            if (parsed.host.isNotEmpty) {
              final port = parsed.hasPort ? ':${parsed.port}' : '';
              return '${parsed.scheme}://${parsed.host}$port';
            }
          }
        }
      }
    }
    return '';
  }
}
