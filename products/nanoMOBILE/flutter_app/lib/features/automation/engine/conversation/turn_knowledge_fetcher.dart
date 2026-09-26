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
// y llamada a transportes externos del contrato del enrutador (< 200 líneas por módulo).

library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_query.dart';
import '../browser/reverse_agent_client.dart';
import '../browser/web_knowledge_service.dart';
import '../mcp/mcp_client_port.dart';
import '../mcp/mcp_connection_registry.dart';
import 'turn_knowledge_router.dart';

part 'turn_knowledge_fetcher_body.part.dart';
