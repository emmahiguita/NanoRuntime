// nano_media_html_extractor.dart — Extractor de recursos multimedia en documentos HTML.
// QUÉ HACE: Inspecciona texto HTML para detectar vídeos OpenGraph, imágenes destacadas, tags <video> y enlaces a PDFs.
// CÓMO FUNCIONA: Aplica expresiones regulares ligeras sin cargar parsers DOM pesados y resuelve URLs relativas a absolutas.
// POR QUÉ: Principio de Responsabilidad Única (SRP) de SOLID: aísla el parseo del contenido web de las peticiones de red HTTP.
library;

import 'nano_ai_models.dart';

class NanoMediaHtmlExtractor {
  const NanoMediaHtmlExtractor();

  /// QUÉ HACE: Analiza el HTML crudo y devuelve la lista de recursos detectados (vídeo, imagen, documento).
  List<NanoMediaResource> extract(String html, Uri baseUri) {
    final resources = <NanoMediaResource>[];

    // 1. Detección OpenGraph Video (og:video)
    final ogVideo = RegExp(
      r'<meta\s+property=["\x27]og:video(?::secure_url)?["\x27]\s+content=["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (ogVideo != null) {
      resources.add(NanoMediaResource(
        url: resolveUrl(ogVideo, baseUri),
        type: NanoMediaType.video,
        title: 'Vídeo principal (${baseUri.host})',
        sourceUrl: baseUri.toString(),
      ));
    }

    // 2. Detección OpenGraph Image (og:image)
    final ogImage = RegExp(
      r'<meta\s+property=["\x27]og:image["\x27]\s+content=["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (ogImage != null) {
      resources.add(NanoMediaResource(
        url: resolveUrl(ogImage, baseUri),
        type: NanoMediaType.image,
        title: 'Imagen destacada (${baseUri.host})',
        sourceUrl: baseUri.toString(),
      ));
    }

    // 3. Enlaces directos a PDFs embebidos (<a href="...pdf">)
    final docLinks = RegExp(
      r'<a[^>]+href=["\x27]([^"\x27]+\.pdf(?:[?#][^"\x27]*)?)["\x27]',
      caseSensitive: false,
    ).allMatches(html);
    for (final m in docLinks) {
      final href = m.group(1);
      if (href != null) {
        final full = resolveUrl(href, baseUri);
        if (resources.every((r) => r.url != full)) {
          final uri = Uri.tryParse(full);
          final title = uri != null ? extractFilename(uri) : 'Documento PDF';
          resources.add(NanoMediaResource(
            url: full,
            type: NanoMediaType.document,
            title: title,
            sourceUrl: baseUri.toString(),
          ));
        }
      }
    }

    // 4. Etiquetas <video src="..."> y <source src="..."> de HTML5
    final videoSrcs = RegExp(
      r'<video[^>]+src=["\x27]([^"\x27]+)["\x27]|<source[^>]+src=["\x27]([^"\x27]+\.(?:mp4|webm))["\x27]',
      caseSensitive: false,
    ).allMatches(html);
    for (final m in videoSrcs) {
      final src = m.group(1) ?? m.group(2);
      if (src != null) {
        final full = resolveUrl(src, baseUri);
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

  /// QUÉ HACE: Convierte una ruta relativa en una URL HTTP absoluta basada en el dominio de origen.
  String resolveUrl(String relative, Uri baseUri) {
    if (relative.startsWith('http://') || relative.startsWith('https://')) {
      return relative;
    }
    return baseUri.resolve(relative).toString();
  }

  /// QUÉ HACE: Extrae el nombre del archivo final de la URI de forma segura.
  String extractFilename(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isNotEmpty && segments.last.isNotEmpty) {
      return segments.last;
    }
    return 'archivo_${uri.host}';
  }
}
