import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/action_tool_adapter.dart';

final class _TextArguments implements ToolArguments {
  const _TextArguments(this.text);
  final String text;
  @override
  Map<String, Object?> toRedactedMap() => {'textLength': text.length};
}

void main() {
  group('Formal tool contracts', () {
    test('execution and verification are independent states', () {
      final result = ToolResult<String>.success(
        output: 'accepted',
        verificationStatus: ToolVerificationStatus.dispatched,
      );
      expect(result.executionStatus, ToolExecutionStatus.success);
      expect(result.verificationStatus, ToolVerificationStatus.dispatched);

      final verified = result.copyWith(
        verificationStatus: ToolVerificationStatus.verified,
      );
      expect(verified.executionStatus, ToolExecutionStatus.success);
      expect(verified.verificationStatus, ToolVerificationStatus.verified);
    });

    test('ToolDefinition separates risk, side effect and approval', () {
      const definition = ToolDefinition(
        id: 'terminal.status',
        version: 2,
        displayName: 'Git status',
        description: 'Read repository status',
        category: ToolCategory.atomicAction,
        risk: ToolRiskLevel.high,
        sideEffect: ToolSideEffect.localRead,
        approvalPolicy: ApprovalPolicy.never,
        allowedExecutionModes: [ToolExecutionMode.foreground],
        tags: {'git', 'read'},
      );
      expect(definition.versionedId, 'terminal.status@2');
      expect(definition.risk, ToolRiskLevel.high);
      expect(definition.approvalPolicy, ApprovalPolicy.never);
      expect(definition.sideEffect, ToolSideEffect.localRead);
    });

    test('ToolExecutionContext preserves parent and correlation identity', () {
      final context = ToolExecutionContext(
        executionId: 'action-541',
        parentExecutionId: 'skill-027',
        correlationId: 'whatsapp-event-718',
        arguments: const _TextArguments('hola'),
        caller: const AgentIdentity(role: AgentCallerRole.personal),
        environment: const ToolExecutionEnvironment(
          mode: ToolExecutionMode.background,
          userPresent: false,
          approvalGranted: true,
        ),
        requestedAt: DateTime.utc(2026, 9, 16),
      );
      expect(context.parentExecutionId, 'skill-027');
      expect(context.correlationId, 'whatsapp-event-718');
      expect(context.arguments.text, 'hola');
    });

    test('verification is optional and absent from ordinary actions', () {
      final action = ActionToolAdapter<_TextArguments, String>(
        definition: const ToolDefinition(
          id: 'memory.search',
          version: 1,
          displayName: 'Search memory',
          description: 'Read memory',
          category: ToolCategory.domainAction,
        ),
        onExecute: (context) async => ToolResult.success(output: 'ok'),
      );
      final registration = TypedToolRegistration(
        tool: action,
        decoder: (raw) => _TextArguments('${raw['text'] ?? ''}'),
      );
      expect(registration.isVerifiable, isFalse);
    });
  });
}
