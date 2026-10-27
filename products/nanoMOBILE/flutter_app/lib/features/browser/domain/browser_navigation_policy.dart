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
/// (snssdk1340, intent, etc.) antes de la inspección del firewall de red.
///
/// POR QUÉ:
/// Evita clasificar erróneamente esquemas de aplicaciones externas como amenazas de red local
/// o puertos cerrados, protegiendo a la vez contra lanzamientos no solicitados desde orígenes no confiables.
class BrowserNavigationPolicy {
  const BrowserNavigationPolicy._();

  static const Set<String> _blockedSchemes = {
    'file',
    'content',
    'chrome',
    'javascript',
  };

  static const Set<String> _internalWebSchemes = {
    'about',
    'blob',
    'data',
  };

  static const Set<String> _phoneSchemes = {
    'tel',
    'sms',
  };

  static const Set<String> _emailSchemes = {
    'mailto',
  };

  static const Set<String> _storeSchemes = {
    'market',
    'itms-apps',
  };

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

  static const Set<String> _tikTokSchemes = {
    'snssdk1340',
    'snssdk1180',
    'snssdk1233',
    'tiktok',
  };

  /// Hosts de proveedores de identidad federada (OAuth).
  ///
  /// Sus flujos de login (Google Identity Services, Apple, GitHub, Microsoft)
  /// requieren `window.open` en modo popup y fallan silenciosamente en WebViews
  /// con multi-ventana deshabilitada. Única lista que habilita popups.
  static const Set<String> _oAuthProviderHosts = {
    'accounts.google.com',
    'appleid.apple.com',
    'github.com',
    'login.microsoftonline.com',
  };

  /// Variantes regionales de los proveedores anteriores bajo sus dominios
  /// raíz (accounts.google.com.mx, accounts.google.co.uk,
  /// login.microsoftonline.de, ...). Seguro porque cualquier subdominio de
  /// esos dominios raíz pertenece al proveedor; el ancla `$` impide sufijos
  /// falsificados tipo accounts.google.com.evil.
  static final RegExp _oAuthRegionalHostPattern = RegExp(
    r'^(accounts\.google\.[a-z]{2,3}(\.[a-z]{2,3})?'
    r'|login\.microsoftonline\.[a-z]{2,3})$',
  );

  static final RegExp _customSchemePattern = RegExp(r'^[a-z][a-z0-9+.-]*$');

  /// Clasifica una URI según su esquema antes de someterla a validaciones de red.
  static NavigationTargetType classifyUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) return NavigationTargetType.unsupported;

    if (scheme == 'http' || scheme == 'https') {
      return NavigationTargetType.web;
    }

    if (_internalWebSchemes.contains(scheme)) {
      return NavigationTargetType.internalWeb;
    }

    if (_phoneSchemes.contains(scheme)) {
      return NavigationTargetType.phone;
    }

    if (_emailSchemes.contains(scheme)) {
      return NavigationTargetType.email;
    }

    if (_storeSchemes.contains(scheme)) {
      return NavigationTargetType.store;
    }

    if (_blockedSchemes.contains(scheme)) {
      return NavigationTargetType.unsupported;
    }

    if (isExternalAppScheme(scheme)) {
      return NavigationTargetType.externalApp;
    }

    return NavigationTargetType.unsupported;
  }

  /// Determina si un esquema corresponde a TikTok (ej. snssdk1340).
  static bool isTikTokScheme(String scheme) {
    final s = scheme.trim().toLowerCase();
    return _tikTokSchemes.contains(s) || s.startsWith('snssdk');
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

    if (isTikTokScheme(s)) {
      return isTikTokOrigin(o);
    }

    if (s == 'whatsapp') {
      return o.contains('whatsapp.com') || o.contains('wa.me');
    }

    if (s == 'tg' || s == 'telegram') {
      return o.contains('telegram.org') || o.contains('t.me');
    }

    if (s == 'instagram') {
      return o.contains('instagram.com');
    }

    if (s == 'twitter' || s == 'x') {
      return o.contains('twitter.com') || o.contains('x.com');
    }

    if (s == 'youtube' || s == 'vnd.youtube') {
      return o.contains('youtube.com') || o.contains('youtu.be');
    }

    return false;
  }

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
    if (_phoneSchemes.contains(s)) return false;
    if (_emailSchemes.contains(s)) return false;
    if (_storeSchemes.contains(s)) return false;
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
      if (uri.scheme == 'about') {
        return uri.toString();
      }
      if (uri.host.isNotEmpty) {
        return uri.host;
      }
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
