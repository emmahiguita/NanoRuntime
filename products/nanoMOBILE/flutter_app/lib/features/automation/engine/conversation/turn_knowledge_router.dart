// turn_knowledge_router.dart
//
// QUÉ HACE:
// Detecta si un mensaje entrante requiere información fáctica externa (Web,
// noticias, clima, cotizaciones, eventos, IA vía Web/MCP) y delega su búsqueda
// a TurnKnowledgeFetcher para obtener respuestas factuales auténticas sin LLM local.
//
// CÓMO FUNCIONA:
// 1. Analiza el texto normalizado con heurísticas léxicas y palabras clave de actualidad/IA.
// 2. Sanitiza información sensible (emails, teléfonos, contraseñas) antes de la consulta.
// 3. Invoca TurnKnowledgeFetcher para ejecutar la cascada (BrowserAi, MCP, Reverse, Web).
//
// POR QUÉ:
// Aplica SOLID (SRP, OCP, DIP) y Clean Architecture, manteniendo cada archivo
// desacoplado, modular y con menos de 150 líneas de código.

library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import '../browser/reverse_agent_client.dart';
import '../browser/web_knowledge_service.dart';
import '../language/dialogue_act_classifier.dart';
import '../language/hybrid_intent_classifier.dart';
import '../mcp/mcp_connection_registry.dart';
import 'knowledge_need_gate.dart';
import 'turn_knowledge_fetcher.dart';

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
    query: '', rawKnowledge: '', source: 'none', hasFacts: false,
  );
}

/// Contrato para enrutamiento y búsqueda de conocimiento externo.
abstract class TurnKnowledgeRouter {
  bool needsExternalKnowledge(String text);
  Future<ExternalKnowledgeResult> fetchKnowledge(String text);
  Future<void> dispose() async {}
}

/// Implementación concreta que delega la cascada a TurnKnowledgeFetcher.
final class RuntimeTurnKnowledgeRouter implements TurnKnowledgeRouter {
  final TurnKnowledgeFetcher _fetcher;

  RuntimeTurnKnowledgeRouter({
    BrowserAiGateway? browserAiGateway,
    McpConnectionRegistry? mcpConnectionRegistry,
    WebKnowledgeService webKnowledgeService = const WebKnowledgeService(),
    ReverseAgentClient reverseAgentClient = const ReverseAgentClient(),
  }) : _fetcher = TurnKnowledgeFetcher(
         browserAiGateway: browserAiGateway,
         mcpConnectionRegistry: mcpConnectionRegistry,
         webKnowledgeService: webKnowledgeService,
         reverseAgentClient: reverseAgentClient,
       );

  static const _externalKeywords = {
    'que paso con', 'que paso hoy', 'viste que paso', 'supiste que paso',
    'sabes algo de', 'noticias de', 'precio del dolar', 'cuanto esta el dolar',
    'precio de bitcoin', 'como quedo el partido', 'quien gano', 'a que hora juega',
    'clima en', 'va a llover', 'cuando sale', 'cuando se estrena', 'android 16',
    'android 17', 'chatgpt', 'deepseek', 'gemini', 'openai', 'inteligencia artificial',
  };

  static const _intentClassifier = HybridIntentClassifier();

  @override
  bool needsExternalKnowledge(String text) {
    final act = const DialogueActClassifier().classify(text).primaryAct;
    final gate = const KnowledgeNeedGate().evaluate(text: text, act: act);
    if (!gate.needsExternalKnowledge) return false;

    final normalized = text.toLowerCase()
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('¿', '')
        .replaceAll('?', '').trim();
    if (normalized.isEmpty) return false;

    final prediction = _intentClassifier.classify(text);
    // Regla crítica: jamás buscar en Internet citas personales, estado de
    // proyectos del dueño, correferencias ni interacciones sociales cotidianas.
    if (prediction.primaryIntent == HybridIntentCategory.personalAppointmentOrPlan ||
        prediction.primaryIntent == HybridIntentCategory.personalProjectOrFact ||
        prediction.primaryIntent == HybridIntentCategory.contextualCoreference ||
        prediction.primaryIntent == HybridIntentCategory.socialEveryday) {
      return false;
    }

    if (prediction.primaryIntent == HybridIntentCategory.externalCurrentKnowledge ||
        prediction.activeIntents.contains(HybridIntentCategory.externalCurrentKnowledge)) {
      return true;
    }

    for (final kw in _externalKeywords) {
      if (normalized.contains(kw)) return true;
    }

    if (normalized.contains('chatgpt') ||
        normalized.contains('deepseek') ||
        normalized.contains('gemini') ||
        normalized.contains('consulta a') ||
        normalized.contains('pregunta a') ||
        normalized.contains('dile a la ia')) {
      return true;
    }

    if ((normalized.startsWith('sabes ') || normalized.startsWith('viste ')) &&
        (normalized.contains('que') ||
            normalized.contains('quien') ||
            normalized.contains('cuando'))) {
      return true;
    }

    return false;
  }

  static String sanitizeExternalQuery(String input) {
    var text = input.trim();
    text = text.replaceAll(
      RegExp(
        r'^(hola|buenos d[ií]as|buenas tardes|buenas noches|oye|disculpa|mira)[,\s]+',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[email]',
    );
    text = text.replaceAll(RegExp(r'(\+?\d[\d\s-]{7,}\d)'), '[telefono]');
    text = text.replaceAll(RegExp(r'\b(?:\d[ -]*?){13,19}\b'), '[tarjeta]');
    text = text.replaceAll(
      RegExp(
        r'(clave|contrase[ñn]a|password|pin)[:\s]+\S+',
        caseSensitive: false,
      ),
      r'$1: [oculto]',
    );
    return text.trim();
  }

  @override
  Future<ExternalKnowledgeResult> fetchKnowledge(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return ExternalKnowledgeResult.empty;

    final sanitized = sanitizeExternalQuery(clean);
    if (sanitized.isEmpty) return ExternalKnowledgeResult.empty;

    debugPrint('[knowledge-router] buscando info externa: "$sanitized"');
    return _fetcher.executeCascade(sanitized);
  }

  @override
  Future<void> dispose() async {
    await _fetcher.dispose();
  }
}
