part of 'mcp_tool_handler.dart';

/// Sintaxis humana separada de la ejecución y validación de herramientas.
extension _McpHumanCommand on McpToolHandler {
  /// Los comandos humanos conservan argumentos JSON exactos y su autorización.
  Future<String> _handleMcpCommand(
    String rest, {
    required Future<ToolOutcome> Function(
      ToolCall call, {
      bool humanInitiated,
      String? executionId,
      ExecutionCancellationToken? cancellation,
    })
    runGuarded,
    String? executionId,
    ExecutionCancellationToken? cancellation,
  }) async {
    final registry = _mcpConnectionRegistry;
    if (registry == null) return 'Registro MCP no disponible.';
    final query = rest.trim();
    final parts = query.split(RegExp(r'\s+'));
    if (query.isEmpty ||
        const {'list', 'listar'}.contains(parts.first.toLowerCase())) {
      return McpCommandListFormatter(registry).format(parts);
    }
    final hasVerb = const {
      'call',
      'ejecutar',
    }.contains(parts.first.toLowerCase());
    if (hasVerb && parts.length < 2) {
      return 'Usa @mcp call servidor/herramienta {"argumento":"valor"}';
    }
    final toolName = parts[hasVerb ? 1 : 0];
    final raw = query
        .substring(query.indexOf(toolName) + toolName.length)
        .trim();
    Map<String, Object?> args = {};
    if (raw.isNotEmpty) {
      try {
        final value = jsonDecode(raw);
        if (value is! Map<String, dynamic>) {
          return 'Los argumentos deben ser un objeto JSON.';
        }
        args = value;
      } on Object {
        return 'Argumentos JSON incompletos o inválidos; no se ejecutó la herramienta.';
      }
    }
    final remote = await resolveRemoteTool(registry, toolName);
    if (remote == null) {
      return 'No se encontró una herramienta MCP única: $toolName.';
    }
    final category = const McpToolProjection().toNanoTool(remote).category;
    return (await runGuarded(
      ToolCall(
        tool: 'mcp.${category.name}',
        args: {...args, 'mcpTool': remote.qualifiedName},
      ),
      humanInitiated: true,
      executionId: executionId,
      cancellation: cancellation,
    )).feedback;
  }
}
