class BrowserUrlResolver {
  static const String defaultSearchUrl = 'https://www.google.com/search?q=';
  static const String homePageUrl = 'https://www.google.com';

  /// Convierte una entrada de texto dada por el usuario en una URL válida para el navegador.
  /// Si la entrada es un término de búsqueda, genera la consulta en Google.
  static String resolveUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return homePageUrl;

    // Si ya especifica esquema conocido
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('file://') ||
        trimmed.startsWith('about:')) {
      return trimmed;
    }

    // Atajos directos a sitios web populares cuando se escribe solo el nombre
    final lower = trimmed.toLowerCase();
    const commonWebsites = {
      'google': 'https://www.google.com',
      'youtube': 'https://www.youtube.com',
      'chatgpt': 'https://chatgpt.com',
      'deepseek': 'https://chat.deepseek.com',
      'wikipedia': 'https://es.wikipedia.org',
      'github': 'https://github.com',
      'facebook': 'https://www.facebook.com',
      'instagram': 'https://www.instagram.com',
      'twitter': 'https://x.com',
      'x': 'https://x.com',
      'reddit': 'https://www.reddit.com',
      'gmail': 'https://mail.google.com',
      'bing': 'https://www.bing.com',
      'yahoo': 'https://www.yahoo.com',
      'amazon': 'https://www.amazon.com',
    };
    if (commonWebsites.containsKey(lower)) {
      return commonWebsites[lower]!;
    }

    // Comprobar si parece una IP con o sin puerto (ej. 192.168.1.1, localhost:8080)
    final ipRegex = RegExp(
      r'^(localhost|(\d{1,3}\.){3}\d{1,3})(:\d+)?(\/.*)?$',
      caseSensitive: false,
    );
    if (ipRegex.hasMatch(trimmed)) {
      return 'http://$trimmed';
    }

    // Comprobar si parece un dominio válido (ej. github.com, chatgpt.com, sub.domain.org/path)
    final domainRegex = RegExp(
      r'^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(:\d+)?(\/.*)?$',
      caseSensitive: false,
    );
    if (!trimmed.contains(' ') && domainRegex.hasMatch(trimmed)) {
      return 'https://$trimmed';
    }

    // En caso contrario, es una consulta de búsqueda
    return '$defaultSearchUrl${Uri.encodeComponent(trimmed)}';
  }

  /// Extrae el dominio legible (host) para mostrar en el título o la barra de direcciones.
  static String extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        return uri.host.replaceFirst(RegExp(r'^www\.'), '');
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  /// Verifica si la URL dada utiliza HTTPS seguro.
  static bool isSecure(String url) {
    return url.startsWith('https://');
  }
}
