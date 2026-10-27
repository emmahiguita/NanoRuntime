// browser_readability_extractor.dart
// QUÉ HACE: Extracción estructurada estilo Mozilla Readability sobre `document.cloneNode(true)`
//   en `flutter_inappwebview` y en modo HTML en segundo plano sin alterar pestañas visibles.
// CÓMO FUNCIONA: Clona el DOM, elimina nodos ruidosos (`nav`, `footer`, `aside`, `script`)
//   y puntúa los contenedores `<article>` y `<main>` devolviendo un `ReadabilityArticle`.
// POR QUÉ: Evita capturas de pantalla o migración a GeckoView y cumple <190 líneas (SOLID).

library;

import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

final class ReadabilityArticle {
  final String title, byline, siteName, publishedTime, excerpt, textContent, url;

  const ReadabilityArticle({
    required this.title,
    this.byline = '',
    this.siteName = '',
    this.publishedTime = '',
    this.excerpt = '',
    required this.textContent,
    this.url = '',
  });

  bool get hasContent => textContent.trim().length >= 40;

  Map<String, Object?> toJson() => {
    'title': title, 'byline': byline, 'siteName': siteName,
    'publishedTime': publishedTime, 'excerpt': excerpt,
    'textContent': textContent, 'url': url,
  };
}

abstract final class BrowserReadabilityExtractor {
  /// Script JS no destructivo (opera estrictamente sobre `document.cloneNode(true)`).
  static const String readabilityCloneJs = '''
(function() {
  try {
    var docClone = document.cloneNode(true);
    var getMeta = function(sel) {
      var el = docClone.querySelector(sel);
      return el ? (el.getAttribute("content") || "").trim() : "";
    };
    var title = getMeta('meta[property="og:title"]') || docClone.title || "";
    var siteName = getMeta('meta[property="og:site_name"]') || location.hostname || "";
    var byline = getMeta('meta[name="author"]') || getMeta('meta[property="article:author"]') || "";
    var publishedTime = getMeta('meta[property="article:published_time"]') || getMeta('meta[name="date"]') || "";
    var excerpt = getMeta('meta[property="og:description"]') || getMeta('meta[name="description"]') || "";
    var noise = docClone.querySelectorAll("script,style,noscript,svg,nav,footer,header,aside,form,iframe,[role='navigation'],[role='banner'],[aria-hidden='true']");
    for (var i = 0; i < noise.length; i++) {
      if (noise[i].parentNode) noise[i].parentNode.removeChild(noise[i]);
    }
    var root = docClone.querySelector("article") || docClone.querySelector("main") || docClone.querySelector("[role='main']") || docClone.body;
    var paragraphs = root ? root.querySelectorAll("p, h1, h2, h3, li") : [];
    var chunks = [];
    for (var j = 0; j < paragraphs.length; j++) {
      var txt = (paragraphs[j].innerText || paragraphs[j].textContent || "").replace(/\\s+/g, " ").trim();
      if (txt.length >= 25) chunks.push(txt);
    }
    var textContent = chunks.length > 0 ? chunks.join("\\n") : ((root ? (root.innerText || root.textContent) : "") || "").replace(/\\s+/g, " ").trim();
    if (!excerpt && chunks.length > 0) excerpt = chunks[0].substring(0, 240);
    return JSON.stringify({
      title: title, byline: byline, siteName: siteName,
      publishedTime: publishedTime, excerpt: excerpt,
      textContent: textContent.substring(0, 8000), url: location.href
    });
  } catch (e) { return ""; }
})();
''';

  /// Extrae el artículo estructurado desde un `InAppWebViewController` sin mutar su DOM.
  static Future<ReadabilityArticle?> extractFromController(InAppWebViewController controller) async {
    try {
      final raw = await controller.evaluateJavascript(source: readabilityCloneJs);
      if (raw == null) return null;
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map<String, dynamic>) {
        final article = ReadabilityArticle(
          title: (decoded['title'] as String?)?.trim() ?? '',
          byline: (decoded['byline'] as String?)?.trim() ?? '',
          siteName: (decoded['siteName'] as String?)?.trim() ?? '',
          publishedTime: (decoded['publishedTime'] as String?)?.trim() ?? '',
          excerpt: (decoded['excerpt'] as String?)?.trim() ?? '',
          textContent: (decoded['textContent'] as String?)?.trim() ?? '',
          url: (decoded['url'] as String?)?.trim() ?? '',
        );
        return article.hasContent ? article : null;
      }
    } catch (_) {}
    return null;
  }

  /// Extrae un `ReadabilityArticle` desde HTML crudo en segundo plano sin tocar pestañas visibles.
  static ReadabilityArticle parseHtml(String rawHtml, {String url = ''}) {
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(rawHtml);
    final title = _decodeEntities(titleMatch?.group(1) ?? '').trim();
    final descMatch = RegExp(r'<meta[^>]+(?:name="description"|property="og:description")[^>]+content="([^"]+)"', caseSensitive: false).firstMatch(rawHtml);
    final excerpt = _decodeEntities(descMatch?.group(1) ?? '').trim();

    var cleaned = rawHtml.replaceAll(
      RegExp(r'<(script|style|noscript|nav|footer|header|aside|svg|form)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true),
      ' ',
    );
    final articleMatch = RegExp(r'<(article|main)[^>]*>(.*?)</\1>', caseSensitive: false, dotAll: true).firstMatch(cleaned);
    if (articleMatch != null) cleaned = articleMatch.group(2) ?? cleaned;

    final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(cleaned);
    final paragraphs = <String>[];
    for (final m in pMatches) {
      final pText = _stripTags(m.group(1) ?? '');
      if (pText.length >= 35) paragraphs.add(pText);
      if (paragraphs.length >= 12) break;
    }

    final textContent = paragraphs.isNotEmpty ? paragraphs.join(' ') : _stripTags(cleaned);
    final bounded = textContent.length > 4000 ? textContent.substring(0, 4000) : textContent;
    return ReadabilityArticle(
      title: title,
      excerpt: excerpt.isNotEmpty ? excerpt : (paragraphs.isNotEmpty ? paragraphs.first : ''),
      textContent: bounded,
      url: url,
    );
  }

  static String _stripTags(String html) => _decodeEntities(
        html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' '),
      ).trim();

  static String _decodeEntities(String input) => input
      .replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"').replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<').replaceAll('&gt;', '>');
}
