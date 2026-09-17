import '../domain/executable_tool.dart';
import '../domain/tool_definition.dart';
import '../domain/tool_input.dart';
import '../domain/tool_permission.dart';
import '../domain/tool_result.dart';
import '../domain/tool_risk.dart';

typedef McpCallHandler =
    Future<Map<String, dynamic>> Function(
      String serverName,
      String toolName,
      Map<String, dynamic> arguments,
    );

final class McpToolAdapter implements RegisteredTool {
  McpToolAdapter({
    required String serverName,
    required String mcpToolName,
    required String description,
    required McpCallHandler callHandler,
    Map<String, dynamic> inputSchema = const {},
    ToolRiskLevel risk = ToolRiskLevel.medium,
    ToolSideEffect sideEffect = ToolSideEffect.externalRead,
    ApprovalPolicy approvalPolicy = ApprovalPolicy.contextual,
    List<ToolPermission> permissions = const [ToolPermission.network],
  }) : _binding = TypedToolRegistration<MapToolArguments, Object?>(
         decoder: MapToolArguments.new,
         tool: _McpExecutable(
           serverName: serverName,
           mcpToolName: mcpToolName,
           callHandler: callHandler,
           definition: ToolDefinition(
             id: 'mcp.$serverName.$mcpToolName',
             version: 1,
             displayName: '$serverName / $mcpToolName',
             description: description,
             category: ToolCategory.mcp,
             risk: risk,
             sideEffect: sideEffect,
             approvalPolicy: approvalPolicy,
             requiredPermissions: permissions,
             allowedExecutionModes: const [
               ToolExecutionMode.foreground,
               ToolExecutionMode.background,
               ToolExecutionMode.headless,
             ],
             inputSchema: inputSchema,
           ),
         ),
       );

  final RegisteredTool _binding;

  @override
  ToolDefinition get definition => _binding.definition;
  @override
  Type get argumentsType => _binding.argumentsType;
  @override
  bool get isVerifiable => _binding.isVerifiable;
  @override
  ToolArguments decode(Map<String, dynamic> raw) => _binding.decode(raw);
  @override
  Future<ToolResult<Object?>> execute(
    ToolExecutionContext<ToolArguments> context,
  ) => _binding.execute(context);
  @override
  Future<ToolVerificationResult> verify(
    ToolExecutionContext<ToolArguments> context,
    ToolResult<Object?> result,
  ) => _binding.verify(context, result);
}

final class _McpExecutable
    implements ExecutableTool<MapToolArguments, Object?> {
  const _McpExecutable({
    required this.serverName,
    required this.mcpToolName,
    required this.callHandler,
    required this.definition,
  });

  final String serverName;
  final String mcpToolName;
  final McpCallHandler callHandler;

  @override
  final ToolDefinition definition;

  @override
  Future<ToolResult<Object?>> execute(
    ToolExecutionContext<MapToolArguments> context,
  ) async {
    final startedAt = DateTime.now();
    final response = await callHandler(
      serverName,
      mcpToolName,
      context.arguments.values,
    );
    if (response['isError'] == true) {
      return ToolResult<Object?>.failed(
        failure: ToolFailure(
          code: 'mcp_error',
          message: '${response['error'] ?? 'Error devuelto por MCP'}',
        ),
        startedAt: startedAt,
        executionId: context.executionId,
      );
    }
    return ToolResult<Object?>.success(
      output: response['content'] ?? response,
      startedAt: startedAt,
      executionId: context.executionId,
      evidence: [
        ToolEvidence(
          type: ToolEvidenceType.httpResponse,
          source: 'mcp:$serverName/$mcpToolName',
          timestamp: DateTime.now(),
          data: const {'received': true},
        ),
      ],
    );
  }
}
