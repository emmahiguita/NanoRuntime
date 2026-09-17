import 'dart:convert';

import '../domain/executable_tool.dart';
import '../domain/tool_audit.dart';
import '../domain/tool_input.dart';
import '../domain/tool_result.dart';
import 'tool_executor.dart';
import 'tool_policy_gate.dart';
import 'tool_registry.dart';
import 'tool_verifier.dart';

final class ToolRouter {
  ToolRouter({
    required this.registry,
    required this.policyGate,
    required this.auditTrail,
    this.executor = const ToolExecutor(),
    this.verifier = const ToolVerifier(),
  });

  final IToolRegistry registry;
  final ToolPolicyGate policyGate;
  final ToolAuditTrail auditTrail;
  final ToolExecutor executor;
  final ToolVerifier verifier;
  int _sequence = 0;

  Future<ToolResult<Object?>> dispatch(ToolRequest request) async {
    final tool = registry.resolve(request.toolId, version: request.toolVersion);
    if (tool == null) {
      return _policyFailure(
        request: request,
        decision: PolicyDenied(
          reason: PolicyReason.toolNotFound,
          message:
              'Herramienta "${request.toolId}" no registrada o deshabilitada.',
        ),
        arguments: const MapToolArguments({}),
      );
    }
    final ToolArguments arguments;
    try {
      arguments = tool.decode(request.arguments);
    } on Object catch (error) {
      return _policyFailure(
        request: request,
        tool: tool,
        decision: PolicyDenied(
          reason: PolicyReason.invalidInput,
          message:
              'Entrada inválida para ${tool.definition.versionedId}: $error',
          tool: tool,
        ),
        arguments: MapToolArguments(request.arguments),
      );
    }
    return _dispatchResolved(
      toolId: request.toolId,
      toolVersion: request.toolVersion,
      arguments: arguments,
      caller: request.caller,
      environment: request.environment,
      conversation: request.conversation,
      parentExecutionId: request.parentExecutionId,
      correlationId: request.correlationId,
      requestedAt: request.requestedAt,
      preResolvedTool: tool,
    );
  }

  Future<ToolResult<Object?>> dispatchTyped<A extends ToolArguments>(
    TypedToolRequest<A> request,
  ) => _dispatchResolved(
    toolId: request.toolId,
    toolVersion: request.toolVersion,
    arguments: request.arguments,
    caller: request.caller,
    environment: request.environment,
    conversation: request.conversation,
    parentExecutionId: request.parentExecutionId,
    correlationId: request.correlationId,
    requestedAt: request.requestedAt,
  );

  Future<ToolResult<Object?>> _dispatchResolved({
    required String toolId,
    required ToolArguments arguments,
    required AgentIdentity caller,
    required ToolExecutionEnvironment environment,
    int? toolVersion,
    ToolConversationIdentity? conversation,
    String? parentExecutionId,
    String? correlationId,
    DateTime? requestedAt,
    RegisteredTool? preResolvedTool,
  }) async {
    final executionId = _nextExecutionId(toolId);
    final requested = requestedAt ?? DateTime.now();
    final tool =
        preResolvedTool ?? registry.resolve(toolId, version: toolVersion);
    final decision = policyGate.evaluate(
      toolId: toolId,
      toolVersion: toolVersion,
      arguments: arguments,
      caller: caller,
      environment: environment,
    );
    if (decision is! PolicyAllowed || tool == null) {
      return _policyFailureFromValues(
        toolId: toolId,
        toolVersion: toolVersion,
        arguments: arguments,
        caller: caller,
        environment: environment,
        conversation: conversation,
        parentExecutionId: parentExecutionId,
        correlationId: correlationId,
        executionId: executionId,
        requestedAt: requested,
        tool: tool,
        decision: decision,
      );
    }
    if (arguments.runtimeType != tool.argumentsType) {
      return _policyFailureFromValues(
        toolId: toolId,
        toolVersion: toolVersion,
        arguments: arguments,
        caller: caller,
        environment: environment,
        conversation: conversation,
        parentExecutionId: parentExecutionId,
        correlationId: correlationId,
        executionId: executionId,
        requestedAt: requested,
        tool: tool,
        decision: PolicyDenied(
          reason: PolicyReason.invalidInput,
          message:
              'Argumentos ${arguments.runtimeType} incompatibles; se esperaba ${tool.argumentsType}.',
          tool: tool,
        ),
      );
    }
    final context = ToolExecutionContext<ToolArguments>(
      executionId: executionId,
      arguments: arguments,
      caller: caller,
      environment: environment,
      conversation: conversation,
      parentExecutionId: parentExecutionId,
      correlationId: correlationId,
      requestedAt: requested,
    );
    var result = await executor.execute(tool: tool, context: context);
    result = await verifier.verifyIfRequired(
      tool: tool,
      context: context,
      executionResult: result,
    );
    return _auditAndReturn(
      tool: tool,
      context: context,
      arguments: arguments,
      decision: decision,
      result: result,
    );
  }

  Future<ToolResult<Object?>> _policyFailure({
    required ToolRequest request,
    required PolicyDecision decision,
    required ToolArguments arguments,
    RegisteredTool? tool,
  }) => _policyFailureFromValues(
    toolId: request.toolId,
    toolVersion: request.toolVersion,
    arguments: arguments,
    caller: request.caller,
    environment: request.environment,
    conversation: request.conversation,
    parentExecutionId: request.parentExecutionId,
    correlationId: request.correlationId,
    executionId: _nextExecutionId(request.toolId),
    requestedAt: request.requestedAt ?? DateTime.now(),
    tool: tool,
    decision: decision,
  );

  Future<ToolResult<Object?>> _policyFailureFromValues({
    required String toolId,
    required int? toolVersion,
    required ToolArguments arguments,
    required AgentIdentity caller,
    required ToolExecutionEnvironment environment,
    required ToolConversationIdentity? conversation,
    required String? parentExecutionId,
    required String? correlationId,
    required String executionId,
    required DateTime requestedAt,
    required RegisteredTool? tool,
    required PolicyDecision decision,
  }) async {
    final now = DateTime.now();
    final requiresApproval = decision is PolicyRequiresApproval;
    final message = switch (decision) {
      PolicyDenied value => value.message,
      PolicyRequiresApproval value => value.request.message,
      _ => 'La política no permitió ejecutar $toolId.',
    };
    final result = ToolResult<Object?>(
      executionStatus: requiresApproval
          ? ToolExecutionStatus.requiresApproval
          : ToolExecutionStatus.failed,
      verificationStatus: ToolVerificationStatus.notRequired,
      failure: ToolFailure(
        code: requiresApproval ? 'approval_required' : 'policy_denied',
        message: message,
      ),
      startedAt: requestedAt,
      finishedAt: now,
      executionId: executionId,
    );
    final context = ToolExecutionContext<ToolArguments>(
      executionId: executionId,
      arguments: arguments,
      caller: caller,
      environment: environment,
      conversation: conversation,
      parentExecutionId: parentExecutionId,
      correlationId: correlationId,
      requestedAt: requestedAt,
    );
    return _auditAndReturn(
      tool: tool,
      fallbackToolId: toolId,
      fallbackVersion: toolVersion,
      context: context,
      arguments: arguments,
      decision: decision,
      result: result,
    );
  }

  Future<ToolResult<Object?>> _auditAndReturn({
    required ToolExecutionContext<ToolArguments> context,
    required ToolArguments arguments,
    required PolicyDecision decision,
    required ToolResult<Object?> result,
    RegisteredTool? tool,
    String? fallbackToolId,
    int? fallbackVersion,
  }) async {
    try {
      await auditTrail.append(
        ToolExecutionRecord(
          executionId: context.executionId,
          correlationId: context.correlationId,
          parentExecutionId: context.parentExecutionId,
          toolId: tool?.definition.id ?? fallbackToolId ?? 'unknown',
          toolVersion: tool?.definition.version ?? fallbackVersion ?? 0,
          callerRole: context.caller.role.name,
          conversationId: context.conversation?.id,
          argumentsHash: _hashArguments(arguments),
          policyDecision: decision.auditValue,
          startedAt: result.startedAt,
          finishedAt: result.finishedAt,
          executionStatus: result.executionStatus,
          verificationStatus: result.verificationStatus,
          evidence: result.evidence,
          failureCode: result.failure?.code,
        ),
      );
      return result;
    } on Object catch (error) {
      return result.copyWith(
        failure: ToolFailure(
          code: 'audit_persistence_failed',
          message:
              'La acción terminó, pero su auditoría no pudo persistirse: $error',
        ),
      );
    }
  }

  String _nextExecutionId(String toolId) {
    _sequence++;
    return '${toolId.replaceAll('.', '_')}-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  String _hashArguments(ToolArguments arguments) {
    final canonical = jsonEncode(_canonical(arguments.toRedactedMap()));
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(canonical)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is Iterable) return value.map(_canonical).toList(growable: false);
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    return '$value';
  }
}
