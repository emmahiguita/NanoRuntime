// turn_knowledge_fetcher.dart
//
// QUÉ HACE:
// Ejecuta la cascada de recuperación de conocimiento e inteligencia artificial externa
// a través de BrowserAiGateway (ChatGPT/DeepSeek/Gemini en WebView), MCP tools,
// ReverseAgentClient y WebKnowledgeService (DuckDuckGo/Wikipedia).
//
// CÓMO FUNCIONA:
// 1. Detecta si la consulta invoca un proveedor específico de IA (DeepSeek, ChatGPT, Gemini).
// 2. Consulta en paralelo o cascada el proveedor adecuado vía headless WebView / MCP.
// 3. Obtiene y limpia la respuesta textual fáctica sin alucinaciones.
// 4. Fallback a búsqueda Web fáctica pura si la IA no está disponible.
//
// POR QUÉ:
// Aplica SOLID (Single Responsibility Principle) desacoplando la lógica de conexión
// y llamada a transportes externos del contrato del enrutador de conocimiento (< 160 líneas).

library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_query.dart';
import '../browser/reverse_agent_client.dart';
import '../browser/web_knowledge_service.dart';
import '../mcp/mcp_client_port.dart';
import '../mcp/mcp_connection_registry.dart';
import 'turn_knowledge_router.dart';

/// Ejecutor de cascada para búsqueda de conocimiento e IA externa.
final class TurnKnowledgeFetcher {
  final BrowserAiGateway? _browserAiGateway;
  final McpConnectionRegistry? _mcpRegistry;
  final WebKnowledgeService _webService;
  final ReverseAgentClient _reverseClient;

  const TurnKnowledgeFetcher({
    BrowserAiGateway? browserAiGateway,
    McpConnectionRegistry? mcpConnectionRegistry,
    WebKnowledgeService webKnowledgeService = const WebKnowledgeService(),
    ReverseAgentClient reverseAgentClient = const ReverseAgentClient(),
  }) : _browserAiGateway = browserAiGateway,
       _mcpRegistry = mcpConnectionRegistry,
       _webService = webKnowledgeService,
       _reverseClient = reverseAgentClient;

  /// Ejecuta la cascada completa de proveedores externos.
  Future<ExternalKnowledgeResult> executeCascade(String sanitized) async {
    var providerId = 'auto';
    final lower = sanitized.toLowerCase();
    if (lower.contains('deepseek')) {
      providerId = 'deepseek';
    } else if (lower.contains('chatgpt') || lower.contains('openai')) {
      providerId = 'chatgpt';
    } else if (lower.contains('gemini')) {
      providerId = 'gemini';
    }

    // 1. Búsqueda estructurada (SearXNG / Brave Search + Readability + Wikipedia/DDG)
    // Prioridad para consultas informativas sin depender de automatización DOM de chats web.
    if (providerId == 'auto') {
      try {
        final webRes = await _webService.search(sanitized);
        if (webRes.found && webRes.summary.trim().isNotEmpty) {
          debugPrint('[knowledge-router] HIT Structured/WebKnowledge: ${webRes.title}');
          final factsBuffer = StringBuffer(webRes.summary.trim());
          if (webRes.snippets.isNotEmpty) {
            factsBuffer.write(' · ');
            factsBuffer.write(webRes.snippets.first.trim());
          }
          return ExternalKnowledgeResult(
            query: sanitized,
            rawKnowledge: factsBuffer.toString(),
            source: 'web_search',
          );
        }
      } catch (e) {
        debugPrint('[knowledge-router] error structured web: $e');
      }
    }

    // 2. BrowserAiGateway (solo si se pidió explícitamente o falló la búsqueda estructurada)
    if (_browserAiGateway != null) {
      try {
        final aiRes = await _browserAiGateway.query(
          BrowserAiQuery(
            providerId: providerId,
            prompt:
                'Responde de forma concisa, natural, útil y neutral en español a lo siguiente: $sanitized',
            timeout: const Duration(seconds: 20),
          ),
        );
        if (aiRes.isCompleted && aiRes.content.trim().isNotEmpty) {
          debugPrint('[knowledge-router] HIT BrowserAiGateway: ${aiRes.providerId}');
          return ExternalKnowledgeResult(
            query: sanitized,
            rawKnowledge: aiRes.content.trim(),
            source: 'browser_ai_${aiRes.providerId}',
          );
        }
      } catch (e) {
        debugPrint('[knowledge-router] browser_ai error: $e');
      }
    }

    // 2. Servidores y herramientas MCP conectados
    final mcpReg = _mcpRegistry;
    if (mcpReg != null && mcpReg.servers.isNotEmpty) {
      try {
        for (final server in mcpReg.servers) {
          final client = mcpReg.client(server.id);
          if (client == null) continue;
          final tools = await client.listTools();
          final tool = tools.firstWhere(
            (t) =>
                t.name.contains('search') ||
                t.name.contains('query') ||
                t.name.contains('chat') ||
                t.name.contains('ask'),
            orElse: () => tools.isNotEmpty
                ? tools.first
                : const McpRemoteTool(
                    serverId: '',
                    name: '',
                    inputSchema: {},
                  ),
          );
          if (tool.name.isNotEmpty) {
            final res = await client.callTool(
              McpToolCall(
                serverId: server.id,
                toolName: tool.name,
                arguments: {'query': sanitized, 'prompt': sanitized},
              ),
            );
            if (res.success && res.content.isNotEmpty) {
              final textContent = res.content
                  .map((c) => c.text ?? '')
                  .where((t) => t.isNotEmpty)
                  .join('\n');
              if (textContent.trim().isNotEmpty) {
                debugPrint('[knowledge-router] HIT MCP: ${server.id}/${tool.name}');
                return ExternalKnowledgeResult(
                  query: sanitized,
                  rawKnowledge: textContent.trim(),
                  source: 'mcp_${server.id}_${tool.name}',
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[knowledge-router] mcp error: $e');
      }
    }

    // 3. Reverse Agent bridge (ChatGPT headless)
    try {
      final bridgeHealthy = await _reverseClient.checkHealth();
      if (bridgeHealthy) {
        final res = await _reverseClient.query(
          provider: 'chatgpt',
          prompt: 'Responde de forma concisa y puramente fáctica en 2 líneas: $sanitized',
          timeout: const Duration(seconds: 15),
        );
        if (res.ok && res.response.trim().isNotEmpty) {
          debugPrint('[knowledge-router] HIT ReverseAgent: ${res.actualProvider}');
          return ExternalKnowledgeResult(
            query: sanitized,
            rawKnowledge: res.response.trim(),
            source: res.actualProvider,
          );
        }
      }
    } catch (_) {}

    // 4. Búsqueda web directa (DuckDuckGo / Wikipedia)
    try {
      final webRes = await _webService.search(sanitized);
      if (webRes.found && webRes.summary.trim().isNotEmpty) {
        debugPrint('[knowledge-router] HIT WebKnowledgeService: ${webRes.title}');
        final factsBuffer = StringBuffer(webRes.summary.trim());
        if (webRes.snippets.isNotEmpty) {
          factsBuffer.write(' · ');
          factsBuffer.write(webRes.snippets.first.trim());
        }
        return ExternalKnowledgeResult(
          query: sanitized,
          rawKnowledge: factsBuffer.toString(),
          source: 'web_search',
        );
      }
    } catch (e) {
      debugPrint('[knowledge-router] error web: $e');
    }

    return ExternalKnowledgeResult.empty;
  }

  Future<void> dispose() async {
    try {
      await _reverseClient.stopBridge();
    } catch (_) {}
  }
}
