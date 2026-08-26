/// McpToolRegistry (A14.2) — registro de MCP tools disponibles.
///
/// Fuente de verdad de qué tools MCP existen y su categoría. En A14 el backend
/// MCP es futuro; el registry arranca vacío y se puebla cuando exista el
/// servidor. Las tools externalWrite/privileged NO se exponen como candidates
/// automáticos (requieren governance explícito).
library;

import 'mcp_tool.dart';

class McpToolRegistry {
  final Map<String, McpTool> _tools;

  const McpToolRegistry([Map<String, McpTool> tools = const {}])
    : _tools = tools;

  McpTool? lookup(String id) => _tools[id];

  List<McpTool> get all => List.unmodifiable(_tools.values);

  bool get isEmpty => _tools.isEmpty;
}
