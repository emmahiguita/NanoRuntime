import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/tools/application/tool_policy_gate.dart';
import 'package:nanoai/core/tools/application/tool_registry.dart';
import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/action_tool_adapter.dart';

final class _Args implements ToolArguments {
  const _Args();
  @override
  Map<String, Object?> toRedactedMap() => const {};
}

RegisteredTool _tool({
  required String id,
  ToolRiskLevel risk = ToolRiskLevel.low,
  ToolSideEffect sideEffect = ToolSideEffect.none,
  ApprovalPolicy approvalPolicy = ApprovalPolicy.never,
  List<AgentCallerRole> roles = const [AgentCallerRole.system],
  List<ToolPermission> permissions = const [],
  List<ToolExecutionMode> modes = const [ToolExecutionMode.foreground],
}) {
  return TypedToolRegistration(
    tool: ActionToolAdapter<_Args, void>(
      definition: ToolDefinition(
        id: id,
        version: 1,
        displayName: id,
        description: id,
        category: ToolCategory.domainAction,
        risk: risk,
        sideEffect: sideEffect,
        approvalPolicy: approvalPolicy,
        allowedRoles: roles,
        requiredPermissions: permissions,
        allowedExecutionModes: modes,
      ),
      onExecute: (_) async => ToolResult.success(),
    ),
    decoder: (_) => const _Args(),
  );
}

void main() {
  group('Formal ToolPolicyGate', () {
    late ToolRegistry registry;
    late ToolPolicyGate gate;

    setUp(() {
      registry = ToolRegistry();
      registry.register(_tool(id: 'system.ping'));
      registry.register(
        _tool(
          id: 'whatsapp.reply',
          sideEffect: ToolSideEffect.communication,
          approvalPolicy: ApprovalPolicy.contextual,
          roles: const [AgentCallerRole.personal],
          permissions: const [ToolPermission.notificationReply],
          modes: const [
            ToolExecutionMode.foreground,
            ToolExecutionMode.background,
          ],
        ),
      );
      registry.register(
        _tool(
          id: 'terminal.status',
          risk: ToolRiskLevel.high,
          sideEffect: ToolSideEffect.localRead,
          approvalPolicy: ApprovalPolicy.never,
        ),
      );
      gate = ToolPolicyGate(
        registry: registry,
        permissionProvider: const StaticPermissionProvider({
          ToolPermission.notificationReply,
        }),
      );
    });

    test('returns a typed denial for missing tools', () {
      final decision = gate.evaluate(
        toolId: 'missing.tool',
        arguments: const _Args(),
        caller: const AgentIdentity(role: AgentCallerRole.system),
        environment: const ToolExecutionEnvironment.foreground(),
      );
      expect(decision, isA<PolicyDenied>());
      expect((decision as PolicyDenied).reason, PolicyReason.toolNotFound);
    });

    test('role restrictions are enforced', () {
      final decision = gate.evaluate(
        toolId: 'whatsapp.reply',
        arguments: const _Args(),
        caller: const AgentIdentity(role: AgentCallerRole.business),
        environment: const ToolExecutionEnvironment.foreground(
          approvalGranted: true,
        ),
      );
      expect(decision, isA<PolicyDenied>());
      expect((decision as PolicyDenied).reason, PolicyReason.roleNotAllowed);
    });

    test('background communication cannot bypass contextual approval', () {
      final decision = gate.evaluate(
        toolId: 'whatsapp.reply',
        arguments: const _Args(),
        caller: const AgentIdentity(role: AgentCallerRole.personal),
        environment: const ToolExecutionEnvironment(
          mode: ToolExecutionMode.background,
          userPresent: false,
        ),
      );
      expect(decision, isA<PolicyRequiresApproval>());
    });

    test('explicit standing approval permits background communication', () {
      final decision = gate.evaluate(
        toolId: 'whatsapp.reply',
        arguments: const _Args(),
        caller: const AgentIdentity(role: AgentCallerRole.personal),
        environment: const ToolExecutionEnvironment(
          mode: ToolExecutionMode.background,
          userPresent: false,
          approvalGranted: true,
        ),
      );
      expect(decision, isA<PolicyAllowed>());
    });

    test('risk does not automatically imply approval', () {
      final decision = gate.evaluate(
        toolId: 'terminal.status',
        arguments: const _Args(),
        caller: const AgentIdentity(role: AgentCallerRole.system),
        environment: const ToolExecutionEnvironment.foreground(),
      );
      expect(decision, isA<PolicyAllowed>());
    });

    test('missing permission is denied fail-closed', () {
      final restricted = ToolPolicyGate(
        registry: registry,
        permissionProvider: const StaticPermissionProvider({}),
      );
      final decision = restricted.evaluate(
        toolId: 'whatsapp.reply',
        arguments: const _Args(),
        caller: const AgentIdentity(role: AgentCallerRole.personal),
        environment: const ToolExecutionEnvironment.foreground(
          approvalGranted: true,
        ),
      );
      expect(decision, isA<PolicyDenied>());
      expect((decision as PolicyDenied).reason, PolicyReason.permissionMissing);
    });
  });
}
