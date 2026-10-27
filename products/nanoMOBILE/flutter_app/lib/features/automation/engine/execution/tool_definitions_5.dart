part of 'tool_registry.dart';

/// Herramientas registradas: conserva sintaxis, timeout y compatibilidad.
const _toolDefinitions5 = <ToolDefinition>[
  ToolDefinition(
    name: 'mcp.device',
    timeout: Duration(seconds: 20),
    description:
        'Ejecutar una herramienta MCP que interactúa con el dispositivo',
  ),
  ToolDefinition(
    name: 'mcp.externalWrite',
    timeout: Duration(seconds: 30),
    description:
        'Ejecutar una herramienta MCP con efectos de escritura externa',
    promptSyntax: '{"tool":"mcp.externalWrite","args":{"mcpTool":"<tool_id>"}}',
  ),
  ToolDefinition(
    name: 'mcp.privileged',
    timeout: Duration(seconds: 30),
    description: 'Ejecutar una herramienta MCP con privilegios de sistema',
  ),
  ToolDefinition(
    name: 'dev.inspect_app',
    timeout: Duration(seconds: 20),
    description:
        'Inspeccionar paquete de aplicación instalada, componentes, SDK y permisos',
    promptSyntax:
        '{"tool":"dev.inspect_app","args":{"package":"<package_name>"}}',
  ),
  ToolDefinition(
    name: 'dev.diagnostics',
    timeout: Duration(seconds: 15),
    description:
        'Obtener diagnóstico completo de hardware, SO, capacidades y estado del agente',
    promptSyntax: '{"tool":"dev.diagnostics"}',
  ),
  ToolDefinition(
    name: 'dev.adb',
    timeout: Duration(seconds: 25),
    description:
        'Controlar ADB inalámbrico para emparejar, conectar o ejecutar comandos shell',
    promptSyntax:
        '{"tool":"dev.adb","args":{"subcommand":"devices|shell|connect|pair"}}',
  ),
  ToolDefinition(
    name: 'dev.run_benchmark',
    timeout: Duration(seconds: 30),
    description:
        'Ejecutar benchmark factual de automatización, latencia, auto-reparación y consumo',
    promptSyntax: '{"tool":"dev.run_benchmark"}',
  ),
];
