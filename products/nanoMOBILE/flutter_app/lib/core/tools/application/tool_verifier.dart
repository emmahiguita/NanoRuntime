import '../domain/executable_tool.dart';
import '../domain/tool_input.dart';
import '../domain/tool_result.dart';
import '../domain/tool_risk.dart';

final class ToolVerifier {
  const ToolVerifier();

  Future<ToolResult<Object?>> verifyIfRequired({
    required RegisteredTool tool,
    required ToolExecutionContext<ToolArguments> context,
    required ToolResult<Object?> executionResult,
  }) async {
    if (!executionResult.executionSucceeded) return executionResult;
    final policy = tool.definition.verificationPolicy;
    if (policy == ToolVerificationPolicy.notRequired) {
      return executionResult.verificationStatus ==
              ToolVerificationStatus.pending
          ? executionResult.copyWith(
              verificationStatus: ToolVerificationStatus.notRequired,
            )
          : executionResult;
    }
    if (!tool.isVerifiable) {
      final status = policy == ToolVerificationPolicy.required
          ? ToolVerificationStatus.unknown
          : ToolVerificationStatus.notRequired;
      return executionResult.copyWith(verificationStatus: status);
    }
    try {
      final verification = await tool.verify(context, executionResult);
      return executionResult.copyWith(
        verificationStatus: verification.status,
        evidence: [...executionResult.evidence, ...verification.evidence],
        failure: verification.failure ?? executionResult.failure,
        finishedAt: DateTime.now(),
      );
    } on Object catch (error) {
      return executionResult.copyWith(
        verificationStatus: ToolVerificationStatus.unknown,
        failure: ToolFailure(
          code: 'verification_exception',
          message: 'La verificación falló: $error',
        ),
        finishedAt: DateTime.now(),
      );
    }
  }
}
