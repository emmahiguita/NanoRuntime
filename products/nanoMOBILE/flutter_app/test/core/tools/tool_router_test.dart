import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/tools/application/tool_policy_gate.dart';
import 'package:nanoai/core/tools/application/tool_registry.dart';
import 'package:nanoai/core/tools/application/tool_router.dart';
import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_audit.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/action_tool_adapter.dart';
import 'package:nanoai/core/tools/infrastructure/mcp_tool_adapter.dart';

final class _NumberArguments implements ToolArguments {
  const _NumberArguments(this.value);
  final int value;
  @override
  Map<String, Object?> toRedactedMap() => {'value': value};
}

ToolDefinition _definition(
  String id, {
  ToolSideEffect sideEffect = ToolSideEffect.none,
  ApprovalPolicy approvalPolicy = ApprovalPolicy.never,
  ToolVerificationPolicy verificationPolicy =
      ToolVerificationPolicy.notRequired,
  Duration timeout = const Duration(seconds: 1),
  List<AgentCallerRole> roles = const [AgentCallerRole.system],
  List<ToolExecutionMode> modes = const [ToolExecutionMode.foreground],
}) => ToolDefinition(
  id: id,
  version: 1,
  displayName: id,
  description: id,
  category: ToolCategory.atomicAction,
  sideEffect: sideEffect,
  approvalPolicy: approvalPolicy,
  verificationPolicy: verificationPolicy,
  timeout: timeout,
  allowedRoles: roles,
  allowedExecutionModes: modes,
);

RegisteredTool _action(
  ToolDefinition definition,
  Future<ToolResult<int>> Function(ToolExecutionContext<_NumberArguments>)
  execute,
) => TypedToolRegistration(
  tool: ActionToolAdapter<_NumberArguments, int>(
    definition: definition,
    onExecute: execute,
  ),
  decoder: (raw) => _NumberArguments((raw['value'] as num?)?.toInt() ?? 0),
);

void main() {
  group('Formal ToolRouter', () {
    late ToolRegistry registry;
    late InMemoryToolAuditTrail audit;
    late ToolRouter router;

    setUp(() {
      registry = ToolRegistry();
      audit = InMemoryToolAuditTrail();
      router = ToolRouter(
        registry: registry,
        policyGate: ToolPolicyGate(
          registry: registry,
          permissionProvider: const StaticPermissionProvider({
            ToolPermission.network,
          }),
        ),
        auditTrail: audit,
      );
    });

    test(
      'duplicate tool IDs fail bootstrap and frozen registry rejects mutation',
      () {
        final tool = _action(
          _definition('math.identity'),
          (context) async =>
              ToolResult.success(output: context.arguments.value),
        );
        registry.register(tool);
        expect(() => registry.register(tool), throwsStateError);
        registry.freeze();
        expect(
          () => registry.register(
            _action(
              _definition('math.other'),
              (_) async => ToolResult.success(output: 1),
            ),
          ),
          throwsStateError,
        );
      },
    );

    test('missing tool never reaches an executor and is audited', () async {
      final result = await router.dispatch(
        const ToolRequest(
          toolId: 'missing.tool',
          arguments: {},
          caller: AgentIdentity(role: AgentCallerRole.system),
          environment: ToolExecutionEnvironment.foreground(),
        ),
      );
      expect(result.executionStatus, ToolExecutionStatus.failed);
      expect(result.failure?.code, 'policy_denied');
      expect(
        (await audit.recent()).single.policyDecision,
        'denied:toolNotFound',
      );
    });

    test('policy denial and approval pause never call execute', () async {
      var calls = 0;
      registry.register(
        _action(
          _definition(
            'whatsapp.reply',
            sideEffect: ToolSideEffect.communication,
            approvalPolicy: ApprovalPolicy.contextual,
            roles: const [AgentCallerRole.personal],
            modes: const [
              ToolExecutionMode.foreground,
              ToolExecutionMode.background,
            ],
          ),
          (_) async {
            calls++;
            return ToolResult.success(output: 1);
          },
        ),
      );
      final denied = await router.dispatchTyped(
        const TypedToolRequest(
          toolId: 'whatsapp.reply',
          arguments: _NumberArguments(1),
          caller: AgentIdentity(role: AgentCallerRole.business),
          environment: ToolExecutionEnvironment.foreground(),
        ),
      );
      expect(denied.executionStatus, ToolExecutionStatus.failed);
      final approval = await router.dispatchTyped(
        const TypedToolRequest(
          toolId: 'whatsapp.reply',
          arguments: _NumberArguments(1),
          caller: AgentIdentity(role: AgentCallerRole.personal),
          environment: ToolExecutionEnvironment(
            mode: ToolExecutionMode.background,
            userPresent: false,
          ),
        ),
      );
      expect(approval.executionStatus, ToolExecutionStatus.requiresApproval);
      expect(calls, 0);
    });

    test(
      'external timeout is timedOut + unknown and never false FAILED',
      () async {
        registry.register(
          _action(
            _definition(
              'external.write',
              sideEffect: ToolSideEffect.externalWrite,
              timeout: const Duration(milliseconds: 20),
            ),
            (_) async {
              await Completer<void>().future;
              return ToolResult.success(output: 1);
            },
          ),
        );
        final result = await router.dispatchTyped(
          const TypedToolRequest(
            toolId: 'external.write',
            arguments: _NumberArguments(1),
            caller: AgentIdentity(role: AgentCallerRole.system),
            environment: ToolExecutionEnvironment.foreground(),
          ),
        );
        expect(result.executionStatus, ToolExecutionStatus.timedOut);
        expect(result.verificationStatus, ToolVerificationStatus.unknown);
        expect(result.failure?.retryable, isFalse);
      },
    );

    test('DISPATCHED is not promoted to VERIFIED automatically', () async {
      final executable = VerifiableActionToolAdapter<_NumberArguments, int>(
        definition: _definition(
          'message.send',
          verificationPolicy: ToolVerificationPolicy.required,
        ),
        onExecute: (_) async => ToolResult.success(
          output: 1,
          verificationStatus: ToolVerificationStatus.dispatched,
        ),
        onVerify: (_, __) async => const ToolVerificationResult(
          status: ToolVerificationStatus.dispatched,
        ),
      );
      registry.register(
        TypedToolRegistration(
          tool: executable,
          decoder: (raw) => const _NumberArguments(1),
        ),
      );
      final result = await router.dispatchTyped(
        const TypedToolRequest(
          toolId: 'message.send',
          arguments: _NumberArguments(1),
          caller: AgentIdentity(role: AgentCallerRole.system),
          environment: ToolExecutionEnvironment.foreground(),
        ),
      );
      expect(result.executionStatus, ToolExecutionStatus.success);
      expect(result.verificationStatus, ToolVerificationStatus.dispatched);
    });

    test(
      'verifier exception becomes UNKNOWN while execution remains SUCCESS',
      () async {
        final executable = VerifiableActionToolAdapter<_NumberArguments, int>(
          definition: _definition(
            'message.verifyThrows',
            verificationPolicy: ToolVerificationPolicy.required,
          ),
          onExecute: (_) async => ToolResult.success(
            output: 1,
            verificationStatus: ToolVerificationStatus.pending,
          ),
          onVerify: (_, __) async => throw StateError('verifier failed'),
        );
        registry.register(
          TypedToolRegistration(
            tool: executable,
            decoder: (raw) => const _NumberArguments(1),
          ),
        );
        final result = await router.dispatchTyped(
          const TypedToolRequest(
            toolId: 'message.verifyThrows',
            arguments: _NumberArguments(1),
            caller: AgentIdentity(role: AgentCallerRole.system),
            environment: ToolExecutionEnvironment.foreground(),
          ),
        );
        expect(result.executionStatus, ToolExecutionStatus.success);
        expect(result.verificationStatus, ToolVerificationStatus.unknown);
        expect(result.failure?.code, 'verification_exception');
      },
    );

    test('child execution keeps parent and correlation in audit', () async {
      registry.register(
        _action(
          _definition('child.read'),
          (context) async =>
              ToolResult.success(output: context.arguments.value),
        ),
      );
      await router.dispatchTyped(
        const TypedToolRequest(
          toolId: 'child.read',
          arguments: _NumberArguments(7),
          caller: AgentIdentity(role: AgentCallerRole.system),
          environment: ToolExecutionEnvironment.foreground(),
          parentExecutionId: 'skill-027',
          correlationId: 'whatsapp-event-718',
        ),
      );
      final record = (await audit.recent()).single;
      expect(record.parentExecutionId, 'skill-027');
      expect(record.correlationId, 'whatsapp-event-718');
      expect(record.argumentsHash, isNotEmpty);
    });

    test('MCP adapter enters through policy, timeout and audit', () async {
      registry.register(
        McpToolAdapter(
          serverName: 'filesystem',
          mcpToolName: 'read_file',
          description: 'Read a file',
          approvalPolicy: ApprovalPolicy.never,
          callHandler: (_, __, ___) async => {
            'content': 'hello',
            'isError': false,
          },
        ),
      );
      final result = await router.dispatch(
        const ToolRequest(
          toolId: 'mcp.filesystem.read_file',
          arguments: {'path': '/tmp/test'},
          caller: AgentIdentity(role: AgentCallerRole.system),
          environment: ToolExecutionEnvironment.foreground(),
        ),
      );
      expect(result.executionStatus, ToolExecutionStatus.success);
      expect(result.output, 'hello');
      expect((await audit.recent()).single.toolId, 'mcp.filesystem.read_file');
    });
  });
}
