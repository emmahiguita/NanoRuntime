/// Typed tool contracts and their type-erased registry binding.
library;

import 'tool_definition.dart';
import 'tool_input.dart';
import 'tool_result.dart';

abstract interface class ExecutableTool<A extends ToolArguments, O> {
  ToolDefinition get definition;
  Future<ToolResult<O>> execute(ToolExecutionContext<A> context);
}

/// Optional capability. Read-only/local tools do not implement it.
abstract interface class VerifiableTool<A extends ToolArguments, O> {
  Future<ToolVerificationResult> verify(
    ToolExecutionContext<A> context,
    ToolResult<O> result,
  );
}

/// Registry-facing, type-erased binding. Casting remains inside this adapter;
/// action implementations only see their strongly typed arguments.
abstract interface class RegisteredTool {
  ToolDefinition get definition;
  Type get argumentsType;
  bool get isVerifiable;

  ToolArguments decode(Map<String, dynamic> raw);

  Future<ToolResult<Object?>> execute(
    ToolExecutionContext<ToolArguments> context,
  );

  Future<ToolVerificationResult> verify(
    ToolExecutionContext<ToolArguments> context,
    ToolResult<Object?> result,
  );
}

final class TypedToolRegistration<A extends ToolArguments, O>
    implements RegisteredTool {
  const TypedToolRegistration({required this.tool, required this.decoder});

  final ExecutableTool<A, O> tool;
  final ToolArgumentDecoder<A> decoder;

  @override
  ToolDefinition get definition => tool.definition;

  @override
  Type get argumentsType => A;

  @override
  bool get isVerifiable => tool is VerifiableTool<A, O>;

  @override
  ToolArguments decode(Map<String, dynamic> raw) => decoder(raw);

  @override
  Future<ToolResult<Object?>> execute(
    ToolExecutionContext<ToolArguments> context,
  ) async {
    final arguments = context.arguments;
    if (arguments is! A) {
      throw ArgumentError(
        'Argumentos ${arguments.runtimeType} incompatibles con ${definition.versionedId}; se esperaba $A.',
      );
    }
    final typedContext = ToolExecutionContext<A>(
      executionId: context.executionId,
      arguments: arguments,
      caller: context.caller,
      environment: context.environment,
      requestedAt: context.requestedAt,
      conversation: context.conversation,
      parentExecutionId: context.parentExecutionId,
      correlationId: context.correlationId,
    );
    final result = await tool.execute(typedContext);
    return ToolResult<Object?>(
      executionStatus: result.executionStatus,
      verificationStatus: result.verificationStatus,
      output: result.output,
      evidence: result.evidence,
      failure: result.failure,
      startedAt: result.startedAt,
      finishedAt: result.finishedAt,
      executionId: result.executionId,
    );
  }

  @override
  Future<ToolVerificationResult> verify(
    ToolExecutionContext<ToolArguments> context,
    ToolResult<Object?> result,
  ) {
    final arguments = context.arguments;
    if (tool is! VerifiableTool<A, O> || arguments is! A) {
      throw StateError(
        '${definition.versionedId} no implementa VerifiableTool<$A, $O>.',
      );
    }
    final verifier = tool as VerifiableTool<A, O>;
    final typedContext = ToolExecutionContext<A>(
      executionId: context.executionId,
      arguments: arguments,
      caller: context.caller,
      environment: context.environment,
      requestedAt: context.requestedAt,
      conversation: context.conversation,
      parentExecutionId: context.parentExecutionId,
      correlationId: context.correlationId,
    );
    final typedResult = ToolResult<O>(
      executionStatus: result.executionStatus,
      verificationStatus: result.verificationStatus,
      output: result.output is O ? result.output as O : null,
      evidence: result.evidence,
      failure: result.failure,
      startedAt: result.startedAt,
      finishedAt: result.finishedAt,
      executionId: result.executionId,
    );
    return verifier.verify(typedContext, typedResult);
  }
}
