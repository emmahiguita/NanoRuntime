import 'dart:convert';
import 'dart:io';

import 'chrome_content_extractor.dart';
import 'structured_search_client.dart';
import '../perception/nano_snapshot.dart';

/// Cita de una fuente web consultada.
class WebSourceCitation {
  final String title;
  final String url;
  final String providerName;

  const WebSourceCitation({
    required this.title,
    required this.url,
    required this.providerName,
  });
}

/// Resultado estructurado de una consulta de conocimiento en internet.
class WebKnowledgeResult {
  final String query;
  final String title;
  final String summary;
  final List<String> snippets;
  final String? sourceUrl;
  final List<WebSourceCitation> citations;
  final bool found;

  const WebKnowledgeResult({
    required this.query,
    required this.title,
    required this.summary,
    this.snippets = const [],
    this.sourceUrl,
    this.citations = const [],
    this.found = true,
  });

  /// Formatea el resultado en Markdown listo para renderizarse en el chat de Nano.
  String toChatResponse() {
    if (!found || (summary.isEmpty && snippets.isEmpty)) {
      return '### 🌐 Búsqueda Web: "$query"\n\n'
          'No se encontró información concluyente en las fuentes consultadas en internet. '
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

    if (citations.length >= 2) {
      buffer.writeln('🔍 *Fuentes contrastadas (${citations.length}):*');
      for (final c in citations) {
        buffer.writeln('• ${c.providerName}: [${c.title}](${c.url})');
      }
    } else if (citations.length == 1) {
      final c = citations.first;
      buffer.writeln(
        '🔍 *Fuente consultada (fuente única):* ${c.providerName} — ${c.url}',
      );
    } else if (sourceUrl != null && sourceUrl!.isNotEmpty) {
      buffer.writeln('🔍 *Fuente consultada:* $sourceUrl');
    }

    return buffer.toString().trim();
  }
}

/// Servicio de búsqueda y extracción de conocimiento en vivo desde la web.
/// Cumple SRP: consulta APIs de conocimiento público, extrae resúmenes limpios
/// y contrasta múltiples fuentes sin requerir API keys de pago.
class WebKnowledgeService {
  final HttpClient Function()? _clientFactory;

  const WebKnowledgeService({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory;

  HttpClient _createClient() => _clientFactory?.call() ?? HttpClient();

  /// Realiza una búsqueda web multifuente y devuelve una respuesta estructurada completa.
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

    final structuredClient = StructuredSearchClient(
      clientFactory: _clientFactory,
    );

    // Consulta concurrente a múltiples fuentes independientes (SearXNG/Brave + Wikipedia + DuckDuckGo)
    final responses = await Future.wait([
      _fetchWikipediaSummary(cleanQuery, lang: 'es').catchError((_) => null),
      _fetchDuckDuckGo(cleanQuery).catchError((_) => null),
      structuredClient.search(cleanQuery).catchError((_) => null),
    ]);

    var wikiRes = responses[0];
    final ddgRes = responses[1];
    final structuredRes = responses[2];

    if (structuredRes != null &&
        structuredRes.found &&
        structuredRes.summary.trim().isNotEmpty &&
        (wikiRes == null || wikiRes.summary.isEmpty)) {
      return structuredRes;
    }

    // Si Wikipedia en español no arrojó extracto directo, intentar en inglés
    if (wikiRes == null) {
      try {
        wikiRes = await _fetchWikipediaSummary(cleanQuery, lang: 'en');
      } catch (_) {}
    }

    // 1. Caso multifuente exitoso: Ambas fuentes independientes respondieron
    if (wikiRes != null &&
        ddgRes != null &&
        wikiRes.summary.isNotEmpty &&
        ddgRes.summary.isNotEmpty) {
      final citations = <WebSourceCitation>[
        if (wikiRes.sourceUrl != null)
          WebSourceCitation(
            title: wikiRes.title,
            url: wikiRes.sourceUrl!,
            providerName: 'Wikipedia',
          ),
        if (ddgRes.sourceUrl != null)
          WebSourceCitation(
            title: ddgRes.title,
            url: ddgRes.sourceUrl!,
            providerName: 'DuckDuckGo Instant Answer',
          ),
      ];

      final combinedSnippets = <String>[
        ...wikiRes.snippets,
        if (ddgRes.summary != wikiRes.summary) ddgRes.summary,
        ...ddgRes.snippets,
      ];

      return WebKnowledgeResult(
        query: cleanQuery,
        title: wikiRes.title,
        summary: wikiRes.summary,
        snippets: combinedSnippets,
        citations: citations,
        found: true,
      );
    }

    // 2. Caso fuente única: Wikipedia
    if (wikiRes != null && wikiRes.summary.isNotEmpty) {
      final citations = [
        if (wikiRes.sourceUrl != null)
          WebSourceCitation(
            title: wikiRes.title,
            url: wikiRes.sourceUrl!,
            providerName: 'Wikipedia',
          ),
      ];
      return WebKnowledgeResult(
        query: cleanQuery,
        title: wikiRes.title,
        summary: wikiRes.summary,
        snippets: wikiRes.snippets,
        citations: citations,
        found: true,
      );
    }

    // 3. Caso fuente única: DuckDuckGo
    if (ddgRes != null && ddgRes.summary.isNotEmpty) {
      final citations = [
        if (ddgRes.sourceUrl != null)
          WebSourceCitation(
            title: ddgRes.title,
            url: ddgRes.sourceUrl!,
            providerName: 'DuckDuckGo Instant Answer',
          ),
      ];
      return WebKnowledgeResult(
        query: cleanQuery,
        title: ddgRes.title,
        summary: ddgRes.summary,
        snippets: ddgRes.snippets,
        citations: citations,
        found: true,
      );
    }

    // 4. Intentar búsqueda por lista de temas (Wikipedia Search API)
    try {
      final searchResult = await _searchWikipediaList(cleanQuery, lang: 'es');
      if (searchResult != null && searchResult.found) {
        return searchResult;
      }
    } catch (_) {}

    return WebKnowledgeResult(
      query: cleanQuery,
      title: 'Resultados de búsqueda: "$cleanQuery"',
      summary:
          'Se consultaron fuentes públicas pero no se obtuvo un extracto directo.',
      sourceUrl:
          'https://www.google.com/search?q=${Uri.encodeComponent(cleanQuery)}',
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

  Future<WebKnowledgeResult?> _fetchWikipediaSummary(
    String query, {
    required String lang,
  }) async {
    final encoded = Uri.encodeComponent(query.replaceAll(' ', '_'));
    final url = Uri.parse(
      'https://$lang.wikipedia.org/api/rest_v1/page/summary/$encoded',
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

  Future<WebKnowledgeResult?> _searchWikipediaList(
    String query, {
    required String lang,
  }) async {
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
      final items =
          (data['query']?['search'] as List?)?.cast<Map<String, dynamic>>() ??
          [];
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
        sourceUrl:
            'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(firstTitle)}',
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
