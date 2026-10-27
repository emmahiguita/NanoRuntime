import 'dart:convert';

import '../../mcp/mcp_client_port.dart';
import '../../mcp/mcp_connection_registry.dart';
import '../../mcp/mcp_tool.dart';
import '../../mcp/mcp_tool_projection.dart';
import '../../mcp/mcp_tool_resolver.dart';
import '../../voice/execution_cancellation.dart';
import '../tool_call.dart';
import '../tool_outcome.dart';
import 'mcp_command_list_formatter.dart';
import '../tool_execution_report.dart';
import '../../mcp/mcp_schema_validator.dart';
import '../../mcp/mcp_result_presenter.dart';
part 'mcp_human_command.dart';

/// Manejador de herramientas y comandos MCP (Model Context Protocol).
/// Cumple SRP: descubrimiento y ejecución remota de herramientas MCP.
class McpToolHandler {
  final McpConnectionRegistry? _mcpConnectionRegistry;

  const McpToolHandler({McpConnectionRegistry? mcpConnectionRegistry})
    : _mcpConnectionRegistry = mcpConnectionRegistry;

  Future<String> handleMcpCommand(
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
  }) => _handleMcpCommand(
    rest,
    runGuarded: runGuarded,
    executionId: executionId,
    cancellation: cancellation,
  );

  final McpToolResolver _resolver = const McpToolResolver();

  Future<McpRemoteTool?> resolveRemoteTool(
    McpConnectionRegistry registry,
    String requested,
  ) => _resolver.resolve(registry, requested);

  /// API legacy: devuelve texto; el dispatcher nuevo consume executeReport.
  Future<String> executeMcpTool(ToolCall call) async =>
      (await executeReport(call)).feedback;

  /// Valida identidad, clasificación y JSON Schema antes del único efecto físico.
  Future<ToolExecutionReport> executeReport(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) async {
    ToolExecutionReport fail(String message) =>
        ToolExecutionReport(message, ToolExecutionStatus.failed);
    final requested =
        call.args?['mcpTool'] ??
        call.args?['tool'] ??
        call.selectorArg ??
        call.textArg;
    if (requested is! String || requested.isEmpty) {
      return fail('Falta el identificador mcpTool.');
    }
    final registry = _mcpConnectionRegistry;
    if (registry == null) return fail('Registro MCP no disponible.');
    final remote = await resolveRemoteTool(registry, requested);
    cancellation?.throwIfCancelled();
    if (remote == null) {
      return fail('Herramienta MCP ausente o ambigua: $requested.');
    }
    final projection = const McpToolProjection().toNanoTool(remote);
    if (call.tool != 'mcp.${projection.category.name}') {
      return fail(
        'La clasificación de la herramienta no coincide con su autorización.',
      );
    }
    final args = Map<String, Object?>.from(call.args ?? {})..remove('mcpTool');
    final errors = await McpSchemaValidator.validate(remote.inputSchema, args);
    if (errors.isNotEmpty) return fail(errors.join('\n'));
    cancellation?.throwIfCancelled();
    final client = registry.client(remote.serverId);
    if (client == null) return fail('El servidor ya no está registrado.');
    final result = await client.callTool(
      McpToolCall(
        serverId: remote.serverId,
        toolName: remote.name,
        arguments: args,
      ),
    );
    return McpResultPresenter.present(
      result,
      mutating: projection.category != McpToolCategory.read,
    );
  }
}
