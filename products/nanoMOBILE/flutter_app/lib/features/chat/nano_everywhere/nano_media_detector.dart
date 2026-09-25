// nano_media_detector.dart — Analizador de recursos multimedia por URL y página.
// QUÉ: Inspecciona URLs para resolver si son recursos directos o páginas con contenido multimedia.
// CÓMO: Emplea peticiones HEAD/GET ligeras con streaming, parsea cabeceras Content-Type
//       y etiquetas OpenGraph / HTML5 (video, audio, img) sin cargar bibliotecas pesadas de Python.
// POR QUÉ: Extrae recursos de forma nativa en Android sin sobrecargar el hardware ni la memoria RAM.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'nano_ai_models.dart';

class NanoMediaDetector {
  const NanoMediaDetector({http.Client? client, MethodChannel? channel})
      : _client = client,
        _channel = channel;
  final http.Client? _client;
  final MethodChannel? _channel;

  static const MethodChannel _defaultChannel = MethodChannel('dev.nanoai/floating');

  static const List<String> _socialDomains = [
    'youtube.com',
    'youtu.be',
    'twitter.com',
    'x.com',
    'instagram.com',
    'tiktok.com',
    'facebook.com',
    'fb.watch',
    'reddit.com',
  ];

  /// Extrae el primer enlace http/https presente en cualquier texto o prompt.
  static String? extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s<>"]+', caseSensitive: false).firstMatch(text);
    return match?.group(0);
  }

  /// Indica si la URL pertenece a YouTube, Facebook, X/Twitter, Instagram, TikTok o Reddit.
  static bool isSocialMediaUrl(String url) {
    final lower = url.toLowerCase();
    return _socialDomains.any(lower.contains);
  }

  /// Detecta si un prompt de usuario solicita descargar o contiene un enlace de redes sociales/multimedia.
  static bool shouldAutoDetectMedia(String prompt) {
    final url = extractFirstUrl(prompt);
    if (url == null) return false;
    if (isSocialMediaUrl(url)) return true;
    final lower = prompt.toLowerCase();
    return lower.contains('descarga') ||
        lower.contains('download') ||
        lower.contains('bajar') ||
        lower.contains('guardar video') ||
        lower.contains('mp4') ||
        lower.contains('mp3');
  }

  http.Client get _httpClient => _client ?? http.Client();
  MethodChannel get _floatingChannel => _channel ?? _defaultChannel;

  /// Analiza [inputUrl] (o un texto con URL) y descubre los recursos multimedia asociados.
  Future<List<NanoMediaResource>> detect(String inputUrl) async {
    final extracted = extractFirstUrl(inputUrl) ?? inputUrl.trim();
    final uri = Uri.tryParse(extracted);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return const [];
    }

    // 0. Si es una red social soportada (YouTube, FB, X, Instagram, TikTok, Reddit),
    //    usar el puente nativo NanoMediaResolver / NanoSnaptubeSniffer.
    if (isSocialMediaUrl(uri.toString())) {
      final socialItems = await _resolveSocialMediaNatively(uri);
      if (socialItems.isNotEmpty) {
        return socialItems;
      }
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

      final htmlItems = _extractFromHtml(html, uri);
      if (htmlItems.isNotEmpty) return htmlItems;

      // Fallback para redes sociales cuando el entorno no tiene canal nativo (ej. tests)
      if (isSocialMediaUrl(uri.toString())) {
        return _buildFallbackSocialResources(uri);
      }
      return const [];
    } catch (_) {
      // Fallback: si falla por timeout o error de red, clasificar por extensión o red social
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
      if (isSocialMediaUrl(uri.toString())) {
        return _buildFallbackSocialResources(uri);
      }
      return const [];
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<List<NanoMediaResource>> _resolveSocialMediaNatively(Uri uri) async {
    try {
      final raw = await _floatingChannel
          .invokeMethod<Map<Object?, Object?>>('resolveMedia', {
            'url': uri.toString(),
            'audioOnly': false,
          })
          .timeout(const Duration(seconds: 14));
      if (raw != null && raw['ok'] == true) {
        final streamUrl = (raw['downloadUrl'] as String?) ?? uri.toString();
        final service = (raw['sourceService'] as String?) ?? _serviceLabel(uri.host);
        return [
          NanoMediaResource(
            url: streamUrl,
            type: NanoMediaType.video,
            title: 'Video MP4 ($service)',
            quality: 'MP4 · Stream directo',
            sourceUrl: uri.toString(),
          ),
          NanoMediaResource(
            url: streamUrl,
            type: NanoMediaType.audio,
            title: 'Audio MP3 ($service)',
            quality: 'MP3 · Solo audio',
            sourceUrl: uri.toString(),
          ),
        ];
      }
    } catch (_) {
      // En tests o si el canal nativo falla, ofrecer las opciones de descarga directa/nativa
    }
    return _buildFallbackSocialResources(uri);
  }

  List<NanoMediaResource> _buildFallbackSocialResources(Uri uri) {
    final service = _serviceLabel(uri.host);
    return [
      NanoMediaResource(
        url: uri.toString(),
        type: NanoMediaType.video,
        title: 'Video MP4 ($service)',
        quality: 'MP4 · Extractor NanoSnaptube',
        sourceUrl: uri.toString(),
      ),
      NanoMediaResource(
        url: uri.toString(),
        type: NanoMediaType.audio,
        title: 'Audio MP3 ($service)',
        quality: 'MP3 · Solo audio',
        sourceUrl: uri.toString(),
      ),
    ];
  }

  String _serviceLabel(String host) {
    final h = host.toLowerCase();
    if (h.contains('youtu')) return 'YouTube';
    if (h.contains('facebook') || h.contains('fb.watch')) return 'Facebook';
    if (h.contains('twitter') || h.contains('x.com')) return 'X / Twitter';
    if (h.contains('instagram')) return 'Instagram';
    if (h.contains('tiktok')) return 'TikTok';
    if (h.contains('reddit')) return 'Reddit';
    return host;
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
