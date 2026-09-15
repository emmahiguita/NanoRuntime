import 'dart:convert';
import 'dart:io';

import 'chrome_content_extractor.dart';
import '../perception/nano_snapshot.dart';

/// Resultado estructurado de una consulta de conocimiento en internet.
class WebKnowledgeResult {
  final String query;
  final String title;
  final String summary;
  final List<String> snippets;
  final String? sourceUrl;
  final bool found;

  const WebKnowledgeResult({
    required this.query,
    required this.title,
    required this.summary,
    this.snippets = const [],
    this.sourceUrl,
    this.found = true,
  });

  /// Formatea el resultado en Markdown listo para renderizarse en el chat de Nano.
  String toChatResponse() {
    if (!found || (summary.isEmpty && snippets.isEmpty)) {
      return '### 🌐 Búsqueda Web: "$query"\n\n'
          'No se encontró información directa sintetizable para esta consulta en internet. '
          'Intenta reformular los términos de búsqueda.';
    }

    final buffer = StringBuffer('### 🌐 $title\n\n');
    if (summary.isNotEmpty) {
      buffer.writeln(summary);
      buffer.writeln();
    }

    if (snippets.isNotEmpty) {
      buffer.writeln('**Puntos destacados:**');
      for (final s in snippets.take(4)) {
        buffer.writeln('• $s');
      }
      buffer.writeln();
    }

    if (sourceUrl != null && sourceUrl!.isNotEmpty) {
      buffer.writeln('🔍 *Fuente verificada:* $sourceUrl');
    }

    return buffer.toString().trim();
  }
}

/// Servicio de búsqueda y extracción de conocimiento en vivo desde la web.
/// Cumple SRP: consulta APIs de conocimiento público, extrae resúmenes limpios
/// y genera respuestas completas sin requerir API keys de pago.
class WebKnowledgeService {
  final HttpClient Function()? _clientFactory;

  const WebKnowledgeService({
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory;

  HttpClient _createClient() => _clientFactory?.call() ?? HttpClient();

  /// Realiza una búsqueda web y devuelve una respuesta estructurada completa.
  Future<WebKnowledgeResult> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const WebKnowledgeResult(
        query: '',
        title: 'Búsqueda vacía',
        summary: 'Por favor ingresa un término de búsqueda.',
        found: false,
      );
    }

    // 1. Intentar consulta enciclopédica y factual directa (Wikipedia REST API)
    try {
      final direct = await _fetchWikipediaSummary(cleanQuery, lang: 'es');
      if (direct != null && direct.summary.isNotEmpty) {
        return direct;
      }
    } catch (_) {}

    // 2. Intentar búsqueda por lista de temas (Wikipedia Search API)
    try {
      final searchResult = await _searchWikipediaList(cleanQuery, lang: 'es');
      if (searchResult != null && searchResult.found) {
        return searchResult;
      }
    } catch (_) {}

    // 3. Fallback a Wikipedia en inglés si en español no hay resultados
    try {
      final directEn = await _fetchWikipediaSummary(cleanQuery, lang: 'en');
      if (directEn != null && directEn.summary.isNotEmpty) {
        return directEn;
      }
    } catch (_) {}

    // 4. Fallback a DuckDuckGo Instant Answer API
    try {
      final ddg = await _fetchDuckDuckGo(cleanQuery);
      if (ddg != null && ddg.found) {
        return ddg;
      }
    } catch (_) {}

    return WebKnowledgeResult(
      query: cleanQuery,
      title: 'Resultados de búsqueda: "$cleanQuery"',
      summary: 'Se consultaron las fuentes web pero no se obtuvo un extracto directo.',
      sourceUrl: 'https://www.google.com/search?q=${Uri.encodeComponent(cleanQuery)}',
      found: false,
    );
  }

  /// Extrae el contenido directamente desde una pestaña activa de Chrome.
  WebKnowledgeResult extractFromChrome(NanoSnapshot snapshot) {
    const extractor = ChromeContentExtractor();
    final content = extractor.extract(snapshot);
    if (content.isEmpty) {
      return const WebKnowledgeResult(
        query: 'Chrome',
        title: 'Navegador Web',
        summary: 'No hay contenido web visible en Chrome actualmente.',
        found: false,
      );
    }

    return WebKnowledgeResult(
      query: content.title.isNotEmpty ? content.title : 'Chrome Web Content',
      title: content.title.isNotEmpty ? content.title : 'Página web en Chrome',
      summary: content.rawText.length > 2500
          ? '${content.rawText.substring(0, 2500)}…'
          : content.rawText,
      snippets: content.paragraphs.take(4).toList(),
      sourceUrl: content.url,
      found: true,
    );
  }

  Future<WebKnowledgeResult?> _fetchWikipediaSummary(String query, {required String lang}) async {
    final encoded = Uri.encodeComponent(query.replaceAll(' ', '_'));
    final url = Uri.parse('https://$lang.wikipedia.org/api/rest_v1/page/summary/$encoded');
    final client = _createClient();
    try {
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(url).timeout(const Duration(seconds: 8));
      req.headers.set('User-Agent', 'NanoAgent/1.0 (Mobile Assistant)');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final extract = (data['extract'] as String?)?.trim();
      final title = (data['title'] as String?)?.trim() ?? query;
      final pageUrl = data['content_urls']?['desktop']?['page'] as String?;

      if (extract == null || extract.isEmpty) return null;

      return WebKnowledgeResult(
        query: query,
        title: title,
        summary: extract,
        sourceUrl: pageUrl ?? 'https://$lang.wikipedia.org/wiki/$encoded',
        found: true,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<WebKnowledgeResult?> _searchWikipediaList(String query, {required String lang}) async {
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://$lang.wikipedia.org/w/api.php?action=query&list=search&srsearch=$encoded&utf8=&format=json',
    );
    final client = _createClient();
    try {
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(url).timeout(const Duration(seconds: 8));
      req.headers.set('User-Agent', 'NanoAgent/1.0 (Mobile Assistant)');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = (data['query']?['search'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (items.isEmpty) return null;

      final first = items.first;
      final firstTitle = first['title'] as String? ?? query;

      // Intentar obtener el extracto completo del primer resultado
      final firstSummary = await _fetchWikipediaSummary(firstTitle, lang: lang);
      if (firstSummary != null && firstSummary.summary.isNotEmpty) {
        return firstSummary;
      }

      final snippets = <String>[];
      for (final item in items.take(4)) {
        final rawSnippet = (item['snippet'] as String? ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final title = item['title'] as String? ?? '';
        if (rawSnippet.isNotEmpty) {
          snippets.add('**$title**: $rawSnippet');
        }
      }

      return WebKnowledgeResult(
        query: query,
        title: firstTitle,
        summary: snippets.isNotEmpty ? snippets.first : '',
        snippets: snippets.skip(1).toList(),
        sourceUrl: 'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(firstTitle)}',
        found: true,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<WebKnowledgeResult?> _fetchDuckDuckGo(String query) async {
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1&skip_disambig=1',
    );
    final client = _createClient();
    try {
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(url).timeout(const Duration(seconds: 8));
      req.headers.set('User-Agent', 'NanoAgent/1.0 (Mobile Assistant)');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final abstractText = (data['AbstractText'] as String?)?.trim() ?? '';
      final heading = (data['Heading'] as String?)?.trim() ?? query;
      final sourceUrl = data['AbstractURL'] as String?;

      if (abstractText.isNotEmpty) {
        return WebKnowledgeResult(
          query: query,
          title: heading.isNotEmpty ? heading : query,
          summary: abstractText,
          sourceUrl: sourceUrl,
          found: true,
        );
      }

      final related =
          (data['RelatedTopics'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final snippets = <String>[];
      for (final topic in related.take(4)) {
        final text = (topic['Text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) snippets.add(text);
      }

      if (snippets.isNotEmpty) {
        return WebKnowledgeResult(
          query: query,
          title: heading.isNotEmpty ? heading : query,
          summary: snippets.first,
          snippets: snippets.skip(1).toList(),
          sourceUrl: sourceUrl,
          found: true,
        );
      }

      return null;
    } finally {
      client.close(force: true);
    }
  }
}
