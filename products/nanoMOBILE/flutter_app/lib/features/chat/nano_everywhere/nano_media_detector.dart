// nano_media_detector.dart — Analizador de recursos multimedia por URL y página.
// QUÉ: Inspecciona URLs para resolver si son recursos directos o páginas con contenido multimedia.
// CÓMO: Emplea peticiones HEAD/GET ligeras con streaming, parsea cabeceras Content-Type
//       y etiquetas OpenGraph / HTML5 (video, audio, img) sin cargar bibliotecas pesadas de Python.
// POR QUÉ: Extrae recursos de forma nativa en Android sin sobrecargar el hardware ni la memoria RAM.
import 'dart:async';
import 'package:http/http.dart' as http;
import 'nano_ai_models.dart';

class NanoMediaDetector {
  const NanoMediaDetector({http.Client? client}) : _client = client;
  final http.Client? _client;

  http.Client get _httpClient => _client ?? http.Client();

  /// Analiza [inputUrl] y descubre los recursos multimedia asociados.
  Future<List<NanoMediaResource>> detect(String inputUrl) async {
    final uri = Uri.tryParse(inputUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return const [];
    }

    final client = _httpClient;
    try {
      // 1. Verificación rápida de cabecera HTTP HEAD para enlaces directos
      final headReq = http.Request('HEAD', uri)..followRedirects = true;
      final headRes = await client.send(headReq).timeout(const Duration(seconds: 4));
      final contentType = headRes.headers['content-type']?.toLowerCase() ?? '';
      final contentLength = int.tryParse(headRes.headers['content-length'] ?? '');

      if (_isDirectMedia(contentType)) {
        return [
          NanoMediaResource(
            url: uri.toString(),
            type: _classifyMime(contentType),
            title: _extractFilename(uri),
            estimatedBytes: contentLength,
            sourceUrl: uri.toString(),
          ),
        ];
      }

      // 2. Si es una página web (HTML), hacer GET con timeout
      final getReq = http.Request('GET', uri)..followRedirects = true;
      final getRes = await client.send(getReq).timeout(const Duration(seconds: 6));
      final resp = await http.Response.fromStream(getRes);
      final html = resp.body;

      return _extractFromHtml(html, uri);
    } catch (_) {
      // Fallback: si falla por timeout o error de red, clasificar por extensión de URL
      final extType = _classifyExtension(uri.path);
      if (extType != null) {
        return [
          NanoMediaResource(
            url: uri.toString(),
            type: extType,
            title: _extractFilename(uri),
            sourceUrl: uri.toString(),
          ),
        ];
      }
      return const [];
    } finally {
      if (_client == null) client.close();
    }
  }

  bool _isDirectMedia(String mime) =>
      mime.startsWith('video/') ||
      mime.startsWith('image/') ||
      mime.startsWith('audio/') ||
      mime.contains('pdf');

  NanoMediaType _classifyMime(String mime) {
    if (mime.startsWith('video/')) return NanoMediaType.video;
    if (mime.startsWith('image/')) return NanoMediaType.image;
    if (mime.startsWith('audio/')) return NanoMediaType.audio;
    return NanoMediaType.document;
  }

  NanoMediaType? _classifyExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.webm') || lower.endsWith('.mkv')) {
      return NanoMediaType.video;
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
      return NanoMediaType.image;
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.wav') || lower.endsWith('.ogg')) {
      return NanoMediaType.audio;
    }
    if (lower.endsWith('.pdf') || lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return NanoMediaType.document;
    }
    return null;
  }

  String _extractFilename(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isNotEmpty && segments.last.isNotEmpty) {
      return segments.last;
    }
    return 'archivo_${uri.host}';
  }

  List<NanoMediaResource> _extractFromHtml(String html, Uri baseUri) {
    final resources = <NanoMediaResource>[];

    // OpenGraph Video
    final ogVideo = RegExp(r'<meta\s+property=["\x27]og:video(?::secure_url)?["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false)
        .firstMatch(html)?.group(1);
    if (ogVideo != null) {
      resources.add(NanoMediaResource(
        url: _resolveUrl(ogVideo, baseUri),
        type: NanoMediaType.video,
        title: 'Vídeo principal (${baseUri.host})',
        sourceUrl: baseUri.toString(),
      ));
    }

    // OpenGraph Image
    final ogImage = RegExp(r'<meta\s+property=["\x27]og:image["\x27]\s+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false)
        .firstMatch(html)?.group(1);
    if (ogImage != null) {
      resources.add(NanoMediaResource(
        url: _resolveUrl(ogImage, baseUri),
        type: NanoMediaType.image,
        title: 'Imagen destacada (${baseUri.host})',
        sourceUrl: baseUri.toString(),
      ));
    }

    // Enlaces directos a PDFs y documentos embebidos (<a href="...pdf">)
    final docLinks = RegExp(r'<a[^>]+href=["\x27]([^"\x27]+\.pdf(?:[?#][^"\x27]*)?)["\x27]', caseSensitive: false)
        .allMatches(html);
    for (final m in docLinks) {
      final href = m.group(1);
      if (href != null) {
        final full = _resolveUrl(href, baseUri);
        if (resources.every((r) => r.url != full)) {
          final uri = Uri.tryParse(full);
          final title = uri != null ? _extractFilename(uri) : 'Documento PDF';
          resources.add(NanoMediaResource(
            url: full,
            type: NanoMediaType.document,
            title: title,
            sourceUrl: baseUri.toString(),
          ));
        }
      }
    }

    // Tags <video src="..."> y <source src="...">
    final videoSrcs = RegExp(r'<video[^>]+src=["\x27]([^"\x27]+)["\x27]|<source[^>]+src=["\x27]([^"\x27]+\.(?:mp4|webm))["\x27]', caseSensitive: false)
        .allMatches(html);
    for (final m in videoSrcs) {
      final src = m.group(1) ?? m.group(2);
      if (src != null) {
        final full = _resolveUrl(src, baseUri);
        if (resources.every((r) => r.url != full)) {
          resources.add(NanoMediaResource(
            url: full,
            type: NanoMediaType.video,
            title: 'Vídeo detectado (${resources.length + 1})',
            sourceUrl: baseUri.toString(),
          ));
        }
      }
    }

    return resources;
  }

  String _resolveUrl(String relative, Uri baseUri) {
    if (relative.startsWith('http://') || relative.startsWith('https://')) {
      return relative;
    }
    return baseUri.resolve(relative).toString();
  }
}
