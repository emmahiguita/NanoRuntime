import '../domain/executable_tool.dart';
import '../domain/tool_definition.dart';
import '../domain/tool_input.dart';
import '../domain/tool_permission.dart';
import '../domain/tool_result.dart';
import '../domain/tool_risk.dart';

typedef ApiCallHandler =
    Future<Map<String, dynamic>> Function(
      String endpoint,
      Map<String, dynamic> arguments,
    );

final class ApiToolAdapter implements RegisteredTool {
  ApiToolAdapter({
    required String id,
    required String displayName,
    required String description,
    required String endpoint,
    required ApiCallHandler handler,
    Map<String, dynamic> inputSchema = const {},
    ToolRiskLevel risk = ToolRiskLevel.low,
    ToolSideEffect sideEffect = ToolSideEffect.externalRead,
    ApprovalPolicy approvalPolicy = ApprovalPolicy.contextual,
    List<ToolPermission> permissions = const [ToolPermission.network],
  }) : _binding = TypedToolRegistration<MapToolArguments, Object?>(
         decoder: MapToolArguments.new,
         tool: _ApiExecutable(
           endpoint: endpoint,
           handler: handler,
           definition: ToolDefinition(
             id: id,
             version: 1,
             displayName: displayName,
             description: description,
             category: ToolCategory.api,
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

final class _ApiExecutable
    implements ExecutableTool<MapToolArguments, Object?> {
  const _ApiExecutable({
    required this.endpoint,
    required this.handler,
    required this.definition,
  });

  final String endpoint;
  final ApiCallHandler handler;
  @override
  final ToolDefinition definition;

  @override
  Future<ToolResult<Object?>> execute(
    ToolExecutionContext<MapToolArguments> context,
  ) async {
    final startedAt = DateTime.now();
    final response = await handler(endpoint, context.arguments.values);
    return ToolResult<Object?>.success(
      output: response,
      startedAt: startedAt,
      executionId: context.executionId,
      evidence: [
        ToolEvidence(
          type: ToolEvidenceType.httpResponse,
          source: endpoint,
          timestamp: DateTime.now(),
          data: const {'received': true},
        ),
      ],
    );
  }
}
