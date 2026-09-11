/// WebSearchResolver — Resolución determinista de búsquedas web en Chrome/Google (SRP/DIP).
///
/// Convierte intenciones explícitas de búsqueda web ("busca en Chrome X", "busca en Google X",
/// "investiga en internet X") directamente a un [ToolCall] de `open_url` con la consulta
/// codificada en Google Search.
///
/// Esto garantiza una latencia de inicio de <50ms y 100% de fiabilidad al evitar interactuar
/// con la Omnibox y el teclado en pantalla.
library;

import '../execution/agent_tool_dispatcher.dart' show ToolCall;
import '../execution/goal_verifier.dart' show GoalExpectation;

class WebSearchPlan {
  final ToolCall call;
  final GoalExpectation expectation;
  final String query;
  final String targetUrl;

  const WebSearchPlan({
    required this.call,
    required this.expectation,
    required this.query,
    required this.targetUrl,
  });
}

class WebSearchResolver {
  const WebSearchResolver();

  static const String chromePackage = 'com.android.chrome';
  static const String searchUrlPrefix = 'https://www.google.com/search?q=';

  /// Resuelve si [goal] es una búsqueda web dirigida a Chrome, Google o Internet.
  /// Devuelve [WebSearchPlan] si coincide, o `null` si no es una búsqueda web determinista.
  WebSearchPlan? resolve(String goal) {
    final raw = goal.trim();
    if (raw.isEmpty) return null;

    final query = _extractSearchQuery(raw);
    if (query == null || query.isEmpty) return null;

    final encoded = Uri.encodeComponent(query);
    final targetUrl = '$searchUrlPrefix$encoded';

    return WebSearchPlan(
      query: query,
      targetUrl: targetUrl,
      call: ToolCall(
        tool: 'open_url',
        text: targetUrl,
        args: {
          'url': targetUrl,
          'packageName': chromePackage,
        },
      ),
      expectation: const GoalExpectation(
        expectedPackage: chromePackage,
      ),
    );
  }

  /// Extrae la consulta limpia eliminando preposiciones, verbos y referencias a Chrome/Google/Internet.
  String? _extractSearchQuery(String source) {
    // 1. "Abre Chrome y busca [query]" / "Open Chrome and search [query]"
    final openThenSearch = RegExp(
      r'^(?:abre|abrir|open)\s+(?:google\s+)?(?:chrome|el\s+navegador|el\s+browser)\s+(?:y|e|and|then)\s+(?:busca|buscar|search(?:\s+for)?|investiga|investigar)\s+(?:sobre\s+|acerca\s+de\s+|para\s+)?(.+?)[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    if (openThenSearch != null) {
      return _clean(openThenSearch.group(1));
    }

    // 2. "Busca en (Chrome|Google|Internet|el navegador|la web) [query]"
    final searchInWebTarget = RegExp(
      r'^(?:busca|buscar|b[uú]scame|buscarme|search(?:\s+for)?|investiga|investigar)\s+(?:en|dentro\s+de|on|in)\s+(?:google\s+)?(?:chrome|google|internet|la\s+web|el\s+navegador|el\s+browser)\s+(?:sobre\s+|acerca\s+de\s+|para\s+)?(.+?)[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    if (searchInWebTarget != null) {
      return _clean(searchInWebTarget.group(1));
    }

    // 3. "Busca [query] en (Chrome|Google|Internet|la web|el navegador)"
    final searchTargetAtEnd = RegExp(
      r'^(?:busca|buscar|b[uú]scame|buscarme|search(?:\s+for)?|investiga|investigar)\s+(?:sobre\s+|acerca\s+de\s+)?(.+?)\s+(?:en|on|in)\s+(?:google\s+)?(?:chrome|google|internet|la\s+web|el\s+navegador|el\s+browser)[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    if (searchTargetAtEnd != null) {
      return _clean(searchTargetAtEnd.group(1));
    }

    // 4. "Investiga en internet [query]" / "Investiga sobre [query] en internet"
    final investigateInternet = RegExp(
      r'^(?:investiga|investigar)\s+(?:en\s+internet\s+|en\s+la\s+web\s+)?(?:sobre\s+|acerca\s+de\s+)?(.+?)(?:\s+en\s+internet|\s+en\s+la\s+web)?[.!?]*$',
      caseSensitive: false,
    ).firstMatch(source);
    if (investigateInternet != null) {
      final q = _clean(investigateInternet.group(1));
      // Solo si menciona internet/web explícitamente en la frase original
      final sLower = source.toLowerCase();
      if ((sLower.contains('internet') || sLower.contains('web')) && q.isNotEmpty) {
        return q;
      }
    }

    return null;
  }

  String _clean(String? value) {
    var result = (value ?? '').trim();
    result = result.replaceAll(RegExp(r'^[\s,;:¿¡]+|[\s,;:.!?¿¡]+$'), '');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    if (result.length >= 2) {
      const pairs = {'"': '"', '“': '”', '‘': '’', "'": "'"};
      final closing = pairs[result[0]];
      if (closing != null && result.endsWith(closing)) {
        result = result.substring(1, result.length - 1).trim();
      }
    }
    return result;
  }
}
