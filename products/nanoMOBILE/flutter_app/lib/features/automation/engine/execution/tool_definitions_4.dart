part of 'tool_registry.dart';

/// Herramientas registradas: conserva sintaxis, timeout y compatibilidad.
const _toolDefinitions4 = <ToolDefinition>[
  ToolDefinition(
    name: 'browser_ai_query',
    timeout: Duration(minutes: 3),
    description:
        'Consultar a modelos de IA en navegador web (Gemini, ChatGPT, DeepSeek, Claude) en segundo plano (headless) sin abrir ventanas visibles',
    promptSyntax:
        '{"tool":"browser_ai_query","provider":"gemini|chatgpt|deepseek|claude","prompt":"<consulta>"}',
  ),
  ToolDefinition(
    name: 'browser.ai.ask',
    timeout: Duration(minutes: 3),
    description: 'Consultar modelo en navegador (ChatGPT, Gemini, DeepSeek)',
    promptSyntax:
        '{"tool":"browser.ai.ask","args":{"prompt":"<texto>","provider":"auto|chatgpt|deepseek|gemini"}}',
  ),
  ToolDefinition(
    name: 'browser.ai.providers',
    timeout: Duration(seconds: 15),
    description: 'Listar proveedores de IA activos en navegador web',
    promptSyntax: '{"tool":"browser.ai.providers"}',
  ),
  ToolDefinition(
    name: 'browser.ai.open',
    timeout: Duration(seconds: 15),
    description: 'Abrir pestaña de proveedor web de IA en navegador',
  ),
  ToolDefinition(
    name: 'browser.ai.get_response',
    timeout: Duration(seconds: 15),
    description: 'Obtener última respuesta del proveedor web de IA',
  ),
  ToolDefinition(
    name: 'shizuku_query_package',
    timeout: Duration(seconds: 15),
    description:
        'Consultar metadatos de un paquete con privilegios Shizuku (solo lectura)',
  ),
  ToolDefinition(
    name: 'force_stop_package',
    timeout: Duration(seconds: 15),
    description: 'Detener una aplicación con privilegios Shizuku (reversible)',
  ),
  ToolDefinition(
    name: 'install_package',
    timeout: Duration(seconds: 60),
    description: 'Instalar un APK local con privilegios Shizuku (irreversible)',
  ),
  ToolDefinition(
    name: 'grant_specific_permission',
    timeout: Duration(seconds: 15),
    description: 'Conceder un permiso runtime a un paquete con Shizuku',
  ),
  ToolDefinition(
    name: 'mcp.read',
    timeout: Duration(seconds: 15),
    description: 'Ejecutar una herramienta MCP de solo lectura',
    promptSyntax: '{"tool":"mcp.read","args":{"mcpTool":"<tool_id>"}}',
  ),
];
