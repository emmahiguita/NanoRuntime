// structured_search_client.dart
// QUÉ HACE: Búsqueda web estructurada mediante SearXNG (JSON API) y Brave Search API,
//   enriquecida con extracción Mozilla Readability en segundo plano (`BrowserReadabilityExtractor`).
// CÓMO FUNCIONA: Consulta Brave Search o SearXNG, descarga el primer enlace relevante y extrae
//   su artículo limpio sin abrir ni alterar pestañas visibles del usuario.
// POR QUÉ: Permite responder sobre actualidad ("¿viste lo nuevo que sacó Google?") cumpliendo <185 líneas (SOLID).

library;

import 'dart:convert';
import 'dart:io';

import '../../../browser/application/browser_readability_extractor.dart';
import 'web_knowledge_service.dart' show WebKnowledgeResult, WebSourceCitation;

final class StructuredSearchClient {
  final HttpClient Function()? _clientFactory;
  final List<String> searxngBaseUrls;
  final String? braveApiKey;

  const StructuredSearchClient({
    HttpClient Function()? clientFactory,
    this.searxngBaseUrls = const [
      'http://127.0.0.1:8888',
      'https://searx.be',
      'https://search.inetol.net',
    ],
    this.braveApiKey,
  }) : _clientFactory = clientFactory;

  HttpClient _createClient() => _clientFactory?.call() ?? HttpClient();

  /// Ejecuta búsqueda externa estructurada priorizando Brave Search y luego SearXNG JSON.
  Future<WebKnowledgeResult?> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;
    final effectiveBraveKey = braveApiKey ??
        const String.fromEnvironment('BRAVE_SEARCH_API_KEY', defaultValue: '');

    if (effectiveBraveKey.trim().isNotEmpty) {
      final brave = await _searchBrave(clean, effectiveBraveKey.trim());
      if (brave != null && brave.found) return brave;
    }
    for (final baseUrl in searxngBaseUrls) {
      final searx = await _searchSearxng(clean, baseUrl);
      if (searx != null && searx.found) return searx;
    }
    return null;
  }

  Future<WebKnowledgeResult?> _searchBrave(String query, String apiKey) async {
    final client = _createClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.https('api.search.brave.com', '/res/v1/web/search', {'q': query, 'count': '4', 'search_lang': 'es'});
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      req.headers.set('Accept', 'application/json');
      req.headers.set('X-Subscription-Token', apiKey);
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(await res.transform(utf8.decoder).join());
      final results = (decoded is Map ? (decoded['web'] is Map ? decoded['web']['results'] : null) : null);
      if (results is! List || results.isEmpty) return null;
      return await _buildResultFromItems(query: query, rawItems: results, providerLabel: 'Brave Search', contentKey: 'description');
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<WebKnowledgeResult?> _searchSearxng(String query, String baseUrl) async {
    final client = _createClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final base = Uri.parse(baseUrl);
      final uri = base.replace(
        path: '${base.path.replaceAll(RegExp(r'/$'), '')}/search',
        queryParameters: {'q': query, 'format': 'json', 'language': 'es'},
      );
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      req.headers.set('Accept', 'application/json');
      req.headers.set('User-Agent', 'NanoAI-HybridAgent/1.0');
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(await res.transform(utf8.decoder).join());
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List || results.isEmpty) return null;
      return await _buildResultFromItems(query: query, rawItems: results, providerLabel: 'SearXNG', contentKey: 'content');
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<WebKnowledgeResult?> _buildResultFromItems({
    required String query,
    required List<dynamic> rawItems,
    required String providerLabel,
    required String contentKey,
  }) async {
    final snippets = <String>[];
    final citations = <WebSourceCitation>[];
    String? topTitle, topUrl;

    for (final item in rawItems.take(4)) {
      if (item is! Map) continue;
      final title = (item['title'] as String?)?.trim() ?? '';
      final url = (item['url'] as String?)?.trim() ?? '';
      final snippet = (item[contentKey] as String?)?.trim() ?? '';
      if (title.isEmpty || url.isEmpty) continue;
      topTitle ??= title;
      topUrl ??= url;
      if (snippet.isNotEmpty) snippets.add(snippet);
      citations.add(WebSourceCitation(title: title, url: url, providerName: providerLabel));
    }
    if (citations.isEmpty) return null;

    var summary = snippets.isNotEmpty ? snippets.first : '';
    if (topUrl != null) {
      final readable = await _fetchReadableExcerpt(topUrl);
      if (readable != null && readable.isNotEmpty) summary = readable;
    }
    if (summary.isEmpty) return null;

    return WebKnowledgeResult(
      query: query, title: topTitle ?? query, summary: summary,
      snippets: snippets, sourceUrl: topUrl, citations: citations, found: true,
    );
  }

  Future<String?> _fetchReadableExcerpt(String url) async {
    final client = _createClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 3));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Android; NanoAI Readability)');
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      final html = await res.transform(utf8.decoder).take(16).join();
      final article = BrowserReadabilityExtractor.parseHtml(html, url: url);
      if (!article.hasContent) return null;
      return article.excerpt.length >= 60
          ? article.excerpt
          : article.textContent.substring(0, article.textContent.length.clamp(0, 320));
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
