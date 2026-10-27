/// MCP tools (A14) — contrato tipado de una tool MCP externa.
///
/// MCP entra SOLO mediante adapter: MCP tool → typed structured capability →
/// governance (firewall/critic/broker) → execution. Nunca LLM → MCP →
/// unrestricted shell. Cada tool se clasifica por categoría (read/device/
/// externalWrite/privileged) que determina risk + capability.
library;

enum McpToolCategory { read, device, externalWrite, privileged }

class McpTool {
  final String id;
  final String name;
  final McpToolCategory category;
  final String description;
  final Map<String, Object?> inputSchema;

  const McpTool({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    this.inputSchema = const {},
  });
}
