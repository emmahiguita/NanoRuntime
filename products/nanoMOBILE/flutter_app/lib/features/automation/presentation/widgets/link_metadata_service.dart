import 'dart:convert';
import 'package:http/http.dart' as http;

/// [LinkMetadata]
/// Contiene metadatos OpenGraph extraídos de una URL para tarjetas enriquecidas.
class LinkMetadata {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const LinkMetadata({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  bool get hasContent =>
      (title != null && title!.isNotEmpty) ||
      (description != null && description!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
}

/// [LinkMetadataService]
/// Extrae y cachea metadatos OpenGraph (og:title, og:description, og:image) de enlaces web.
abstract final class LinkMetadataService {
  static final _cache = <String, LinkMetadata>{};
  static final _inFlight = <String, Future<LinkMetadata>>{};

  static LinkMetadata? getCached(String url) => _cache[url];

  /// Extrae los metadatos de la URL de manera asíncrona y los guarda en caché.
  static Future<LinkMetadata> fetchMetadata(String url) {
    if (_cache.containsKey(url)) {
      return Future.value(_cache[url]!);
    }
    if (_inFlight.containsKey(url)) {
      return _inFlight[url]!;
    }

    final future = _doFetch(url);
    _inFlight[url] = future;
    return future;
  }

  static Future<LinkMetadata> _doFetch(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return LinkMetadata(url: url, siteName: url);
      }

      final client = http.Client();
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] =
            'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
        ..headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 4));
      
      // Leer máximo 80 KB para obtener las etiquetas <head> sin consumir ancho de banda
      final bytes = <int>[];
      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        if (bytes.length >= 80 * 1024) break;
      }
      client.close();

      final html = utf8.decode(bytes, allowMalformed: true);
      final metadata = parseHtml(url, html);
      _cache[url] = metadata;
      _inFlight.remove(url);
      return metadata;
    } catch (_) {
      final fallback = LinkMetadata(url: url, siteName: Uri.tryParse(url)?.host.replaceFirst('www.', ''));
      _cache[url] = fallback;
      _inFlight.remove(url);
      return fallback;
    }
  }

  /// Parser liviano de HTML para extraer etiquetas OpenGraph.
  static LinkMetadata parseHtml(String url, String html) {
    String? title;
    String? description;
    String? imageUrl;
    String? siteName;

    // 1. og:title / twitter:title / <title>
    final ogTitle = RegExp(r"""<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']""", caseSensitive: false).firstMatch(html) ??
        RegExp(r"""<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']""", caseSensitive: false).firstMatch(html);
    if (ogTitle != null) {
      title = _unescape(ogTitle.group(1));
    } else {
      final tMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
      if (tMatch != null) title = _unescape(tMatch.group(1));
    }

    // 2. og:description / description
    final ogDesc = RegExp(r"""<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']""", caseSensitive: false).firstMatch(html) ??
        RegExp(r"""<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']""", caseSensitive: false).firstMatch(html) ??
        RegExp(r"""<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:description["']""", caseSensitive: false).firstMatch(html);
    if (ogDesc != null) {
      description = _unescape(ogDesc.group(1));
    }

    // 3. og:image / twitter:image
    final ogImg = RegExp(r"""<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']""", caseSensitive: false).firstMatch(html) ??
        RegExp(r"""<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']""", caseSensitive: false).firstMatch(html) ??
        RegExp(r"""<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']""", caseSensitive: false).firstMatch(html);
    if (ogImg != null) {
      var img = ogImg.group(1)?.trim();
      if (img != null && img.isNotEmpty) {
        final baseUri = Uri.tryParse(url);
        if (baseUri != null && !img.startsWith('http://') && !img.startsWith('https://')) {
          img = baseUri.resolve(img).toString();
        }
        imageUrl = img;
      }
    }

    // 4. og:site_name
    final ogSite = RegExp(r"""<meta[^>]+property=["']og:site_name["'][^>]+content=["']([^"']+)["']""", caseSensitive: false).firstMatch(html) ??
        RegExp(r"""<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:site_name["']""", caseSensitive: false).firstMatch(html);
    if (ogSite != null) {
      siteName = _unescape(ogSite.group(1));
    } else {
      siteName = Uri.tryParse(url)?.host.replaceFirst('www.', '');
    }

    return LinkMetadata(
      url: url,
      title: title?.trim(),
      description: description?.trim(),
      imageUrl: imageUrl,
      siteName: siteName?.trim(),
    );
  }

  static String _unescape(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
