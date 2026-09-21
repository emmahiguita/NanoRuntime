import 'dart:convert';

import '../../mcp/mcp_client_port.dart';
import '../../mcp/mcp_connection_registry.dart';
import '../../mcp/mcp_tool_projection.dart';
import '../../mcp/mcp_tool_resolver.dart';
import '../../voice/execution_cancellation.dart';
import '../tool_call.dart';
import '../tool_outcome.dart';

/// Manejador de herramientas y comandos MCP (Model Context Protocol).
/// Cumple SRP: descubrimiento y ejecución remota de herramientas MCP.
class McpToolHandler {
  final McpConnectionRegistry? _mcpConnectionRegistry;

  const McpToolHandler({McpConnectionRegistry? mcpConnectionRegistry})
    : _mcpConnectionRegistry = mcpConnectionRegistry;

  /// Ejecución e inspección directa de servidores y herramientas MCP desde comandos @.
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
  }) async {
    final query = rest.trim();
    final parts = query.split(RegExp(r'\s+'));
    final sub = parts.isEmpty ? '' : parts.first.toLowerCase();

    final mcpReg = _mcpConnectionRegistry;
    if (mcpReg == null) {
      return 'Registro MCP no configurado en este perfil.';
    }

    if (query.isEmpty || sub == 'list' || sub == 'listar') {
      final snapshot = await mcpReg.refreshTools();
      final buf = StringBuffer(
        '🔌 Servidores y herramientas MCP conectadas:\n',
      );
      for (final s in mcpReg.servers) {
        buf.writeln(
          '• Servidor "${s.id}" (${s.displayName}) [${s.transport.name}]',
        );
      }
      if (snapshot.tools.isEmpty) {
        buf.writeln('  (Sin herramientas descubiertas)');
      } else {
        for (final entry in snapshot.tools.entries) {
          buf.writeln('  - ${entry.key}: ${entry.value.description}');
        }
      }
      if (snapshot.failures.isNotEmpty) {
        buf.writeln('\n⚠️ Fallos de descubrimiento:');
        for (final f in snapshot.failures) {
          buf.writeln('  • ${f.serverId}: ${f.reason}');
        }
      }
      return buf.toString().trim();
    }

    String toolName = '';
    Map<String, Object?> args = {};

    if (sub == 'call' || sub == 'ejecutar') {
      if (parts.length < 2) {
        return 'Sintaxis: @mcp call <tool_name> [json_args]. Ej: @mcp call device.diagnostics';
      }
      toolName = parts[1];
      if (parts.length > 2) {
        final rawJson = query
            .substring(query.indexOf(toolName) + toolName.length)
            .trim();
        if (rawJson.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawJson);
            if (decoded is Map<String, dynamic>) {
              args = Map<String, Object?>.from(decoded);
            }
          } catch (_) {
            args = {'input': rawJson};
          }
        }
      }
    } else {
      // Tratar sub como nombre de herramienta directo (ej: @mcp device.diagnostics o @mcp diagnostics)
      toolName = parts.first;
      if (parts.length > 1) {
        final rawJson = query
            .substring(query.indexOf(toolName) + toolName.length)
            .trim();
        if (rawJson.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawJson);
            if (decoded is Map<String, dynamic>) {
              args = Map<String, Object?>.from(decoded);
            }
          } catch (_) {
            args = {'input': rawJson};
          }
        }
      }
    }

    // Las annotations se proyectan ANTES de entrar al pipeline de governance.
    // Antes todas las llamadas @mcp se marcaban como read, incluso una tool de
    // escritura. Tool desconocida degrada fail-closed a externalWrite.
    final remoteTool = await resolveRemoteTool(mcpReg, toolName);
    final guardedTool = remoteTool == null
        ? 'mcp.externalWrite'
        : 'mcp.${const McpToolProjection().toNanoTool(remoteTool).category.name}';
    final call = ToolCall(
      tool: guardedTool,
      args: {'mcpTool': toolName, ...args},
    );
    return (await runGuarded(
      call,
      humanInitiated: true,
      executionId: executionId,
      cancellation: cancellation,
    )).feedback;
  }

  final McpToolResolver _resolver = const McpToolResolver();

  Future<McpRemoteTool?> resolveRemoteTool(
    McpConnectionRegistry registry,
    String requested,
  ) => _resolver.resolve(registry, requested);

  /// Ejecuta una herramienta MCP a través de McpConnectionRegistry.
  Future<String> executeMcpTool(ToolCall call) async {
    final mcpTool =
        (call.args?['mcpTool'] as String?) ??
        (call.args?['tool'] as String?) ??
        call.selectorArg ??
        call.textArg ??
        '';
    if (mcpTool.isEmpty) {
      return '[tool] Llamada MCP requiere argumento "mcpTool".';
    }

    final mcpReg = _mcpConnectionRegistry;
    if (mcpReg == null) {
      return '[tool] MCP no disponible: registry no configurado.';
    }

    String serverId;
    String toolName;
    if (mcpTool.contains('/')) {
      final split = mcpTool.split('/');
      serverId = split[0];
      toolName = split.sublist(1).join('/');
    } else if (mcpTool.contains('.')) {
      final serverIds =
          mcpReg.servers
              .map((server) => server.id)
              .where((id) => mcpTool.startsWith('$id.'))
              .toList(growable: false)
            ..sort((a, b) => b.length.compareTo(a.length));
      if (serverIds.isNotEmpty) {
        serverId = serverIds.first;
        toolName = mcpTool.substring(serverId.length + 1);
      } else {
        final split = mcpTool.split('.');
        serverId = split[0];
        toolName = split.sublist(1).join('.');
      }
    } else {
      serverId = 'device';
      toolName = mcpTool;
    }

    var client = mcpReg.client(serverId);
    if (client == null && mcpReg.servers.isNotEmpty) {
      client = mcpReg.client(mcpReg.servers.first.id);
      serverId = mcpReg.servers.first.id;
    }

    if (client == null) {
      return '[mcpError] No se encontró servidor MCP para "$serverId".';
    }

    final toolArgs = Map<String, Object?>.from(call.args ?? {})
      ..remove('mcpTool');

    final result = await client.callTool(
      McpToolCall(serverId: serverId, toolName: toolName, arguments: toolArgs),
    );

    if (!result.success) {
      return '[mcpError] Error ejecutando $mcpTool: '
          '${result.message ?? result.errorCode ?? result.status.name}';
    }

    final textItems = result.content
        .where((c) => c.text != null && c.text!.isNotEmpty)
        .map((c) => c.text!)
        .join('\n');

    if (textItems.isNotEmpty) {
      return textItems;
    }

    if (result.structuredContent != null) {
      return jsonEncode(result.structuredContent);
    }

    return '[mcpSuccess] Herramienta $mcpTool ejecutada correctamente.';
  }
}
