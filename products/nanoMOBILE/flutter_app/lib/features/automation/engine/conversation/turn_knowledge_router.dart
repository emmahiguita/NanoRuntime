/// TURN KNOWLEDGE ROUTER
///
/// Detecta si un mensaje entrante requiere información fáctica externa (Web,
/// noticias, clima, cotizaciones, eventos) y la recupera usando servicios
/// desacoplados sin depender del LLM local para la búsqueda.
/// Cumple Clean Architecture, SOLID y límite de < 200 líneas.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../browser/reverse_agent_client.dart';
import '../browser/web_knowledge_service.dart';

/// Hechos externos recuperados para un turno.
final class ExternalKnowledgeResult {
  final String query;
  final String rawKnowledge;
  final String source;
  final bool hasFacts;

  const ExternalKnowledgeResult({
    required this.query,
    required this.rawKnowledge,
    required this.source,
    this.hasFacts = true,
  });

  static const empty = ExternalKnowledgeResult(
    query: '',
    rawKnowledge: '',
    source: 'none',
    hasFacts: false,
  );
}

/// Contrato para enrutamiento y búsqueda de conocimiento externo.
abstract interface class TurnKnowledgeRouter {
  bool needsExternalKnowledge(String text);

  Future<ExternalKnowledgeResult> fetchKnowledge(String text);
}

/// Implementación concreta que prioriza WebKnowledgeService y ReverseAgentClient.
final class RuntimeTurnKnowledgeRouter implements TurnKnowledgeRouter {
  const RuntimeTurnKnowledgeRouter({
    WebKnowledgeService webKnowledgeService = const WebKnowledgeService(),
    ReverseAgentClient reverseAgentClient = const ReverseAgentClient(),
  }) : _webService = webKnowledgeService,
       _reverseClient = reverseAgentClient;

  final WebKnowledgeService _webService;
  final ReverseAgentClient _reverseClient;

  static const _externalKeywords = {
    'que paso con',
    'que paso hoy',
    'viste que paso',
    'supiste que paso',
    'sabes algo de',
    'noticias de',
    'precio del dolar',
    'cuanto esta el dolar',
    'precio de bitcoin',
    'como quedo el partido',
    'quien gano',
    'a que hora juega',
    'clima en',
    'va a llover',
    'cuando sale',
    'cuando se estrena',
    'android 16',
    'android 17',
  };

  @override
  bool needsExternalKnowledge(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('¿', '')
        .replaceAll('?', '')
        .trim();
    if (normalized.isEmpty) return false;

    for (final kw in _externalKeywords) {
      if (normalized.contains(kw)) return true;
    }

    // Patrones interrogativos de conocimiento actual
    if ((normalized.startsWith('sabes ') || normalized.startsWith('viste ')) &&
        (normalized.contains('que') ||
            normalized.contains('quien') ||
            normalized.contains('cuando'))) {
      return true;
    }

    return false;
  }

  @override
  Future<ExternalKnowledgeResult> fetchKnowledge(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return ExternalKnowledgeResult.empty;

    debugPrint('[knowledge-router] buscando información externa para: "$clean"');

    // 1. Intentar puente web / navegador si está disponible
    try {
      final bridgeHealthy = await _reverseClient.checkHealth();
      if (bridgeHealthy) {
        final res = await _reverseClient.query(
          provider: 'chatgpt',
          prompt: 'Responde de forma concisa y puramente fáctica en 2 líneas a la siguiente pregunta: $clean',
          timeout: const Duration(seconds: 15),
        );
        if (res.ok && res.response.trim().isNotEmpty) {
          debugPrint('[knowledge-router] HIT ReverseAgent: ${res.actualProvider}');
          return ExternalKnowledgeResult(
            query: clean,
            rawKnowledge: res.response.trim(),
            source: res.actualProvider,
          );
        }
      }
    } catch (_) {}

    // 2. Búsqueda web directa de conocimiento público (DuckDuckGo/Wikipedia/APIs)
    try {
      final webRes = await _webService.search(clean);
      if (webRes.found && webRes.summary.trim().isNotEmpty) {
        debugPrint('[knowledge-router] HIT WebKnowledgeService: ${webRes.title}');
        final factsBuffer = StringBuffer(webRes.summary.trim());
        if (webRes.snippets.isNotEmpty) {
          factsBuffer.write(' · ');
          factsBuffer.write(webRes.snippets.first.trim());
        }
        return ExternalKnowledgeResult(
          query: clean,
          rawKnowledge: factsBuffer.toString(),
          source: 'web_search',
        );
      }
    } catch (e) {
      debugPrint('[knowledge-router] error consultando web: $e');
    }

    return ExternalKnowledgeResult.empty;
  }
}
