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

    // 1. Prefijos de búsqueda y palabras clave profesionales (!yt, yt, !w, wiki, !g, g, !gh, gh, !ai, chat, !ddg, !maps, !img, !r)
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      final prefix = parts[0].toLowerCase();
      final query = parts.sublist(1).join(' ').trim();
      if (query.isNotEmpty) {
        final encodedQuery = Uri.encodeComponent(query);
        switch (prefix) {
          case '!yt':
          case 'yt':
          case '!youtube':
          case 'youtube':
            return 'https://m.youtube.com/results?search_query=$encodedQuery';
          case '!g':
          case 'g':
          case '!google':
            return 'https://www.google.com/search?q=$encodedQuery';
          case '!w':
          case 'w':
          case '!wiki':
          case 'wiki':
          case '!wikipedia':
            return 'https://es.wikipedia.org/w/index.php?search=$encodedQuery';
          case '!gh':
          case 'gh':
          case '!github':
            return 'https://github.com/search?q=$encodedQuery';
          case '!d':
          case '!ddg':
          case 'ddg':
          case 'duck':
            return 'https://duckduckgo.com/?q=$encodedQuery';
          case '!ai':
          case 'ai':
          case '!chat':
          case 'chat':
          case '!deepseek':
            return 'https://chat.deepseek.com/?q=$encodedQuery';
          case '!chatgpt':
            return 'https://chatgpt.com/?q=$encodedQuery';
          case '!maps':
          case 'maps':
          case '!map':
            return 'https://www.google.com/maps/search/$encodedQuery';
          case '!img':
          case 'img':
          case '!images':
            return 'https://www.google.com/search?tbm=isch&q=$encodedQuery';
          case '!r':
          case 'r/':
          case 'reddit':
            return 'https://www.reddit.com/search/?q=$encodedQuery';
          case '!news':
          case 'news':
            return 'https://news.google.com/search?q=$encodedQuery';
        }
      }
    }

    // 2. Atajos directos a sitios web populares cuando se escribe solo el nombre
    final lower = trimmed.toLowerCase();
    const commonWebsites = {
      'google': 'https://www.google.com',
      'g': 'https://www.google.com',
      'youtube': 'https://m.youtube.com',
      'yt': 'https://m.youtube.com',
      'chatgpt': 'https://chatgpt.com',
      'openai': 'https://chatgpt.com',
      'deepseek': 'https://chat.deepseek.com',
      'wikipedia': 'https://es.wikipedia.org',
      'wiki': 'https://es.wikipedia.org',
      'github': 'https://github.com',
      'gh': 'https://github.com',
      'facebook': 'https://www.facebook.com',
      'instagram': 'https://www.instagram.com',
      'twitter': 'https://x.com',
      'x': 'https://x.com',
      'reddit': 'https://www.reddit.com',
      'gmail': 'https://mail.google.com',
      'maps': 'https://maps.google.com',
      'bing': 'https://www.bing.com',
      'yahoo': 'https://www.yahoo.com',
      'amazon': 'https://www.amazon.com',
      'claude': 'https://claude.ai',
      'gemini': 'https://gemini.google.com',
      'tiktok': 'https://www.tiktok.com',
      'netflix': 'https://www.netflix.com',
      'spotify': 'https://open.spotify.com',
      'linkedin': 'https://www.linkedin.com',
      'duckduckgo': 'https://duckduckgo.com',
      'ddg': 'https://duckduckgo.com',
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
