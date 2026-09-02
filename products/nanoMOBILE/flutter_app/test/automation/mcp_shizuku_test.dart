import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/governance/action_governance_pipeline.dart';
import 'package:nanoai/features/automation/engine/governance/intent_firewall.dart';
import 'package:nanoai/features/automation/engine/governance/intent_spec.dart';
import 'package:nanoai/features/automation/engine/governance/pre_action_critic.dart';
import 'package:nanoai/features/automation/engine/governance/privilege_broker.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_tool.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_tool_adapter.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/privilege/shizuku_capability.dart';
import 'package:nanoai/features/automation/engine/system/capability_availability.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_graph.dart';
import 'package:nanoai/features/automation/engine/system/system_models.dart';

const pipeline = ActionGovernancePipeline(
  firewall: IntentFirewall(),
  critic: PreActionCritic(),
  broker: PrivilegeBroker(),
);

SystemGraph graphWithShizukuUnavailable() => const SystemGraph(
  device: DeviceProfile(manufacturer: '', model: '', sdkInt: 0, release: ''),
  apps: [],
  roles: [],
  capabilities: {
    SystemCapability.shizuku: CapabilityAvailability(
      capability: SystemCapability.shizuku,
      state: CapabilityAvailabilityKind.unsupported,
      reason: 'no backend',
    ),
  },
);

void main() {
  test('MCP read → channel mcp, risk read → approved (publicAndroid)', () {
    final candidate = const McpToolAdapter().adapt(
      const McpTool(
        id: 'read_file',
        name: 'read_file',
        category: McpToolCategory.read,
      ),
      const {'path': '/tmp/x'},
    );
    expect(candidate.channel, ActionChannel.mcp);
    const intent = IntentSpec(id: 'x', allowedEffects: {ActionEffect.read});
    final outcome = pipeline.govern(intent, candidate);
    expect(outcome, isA<GovernanceApproved>());
  });

  test('MCP privileged → capability shizuku → denied (unavailable)', () {
    final candidate = const McpToolAdapter().adapt(
      const McpTool(
        id: 'admin',
        name: 'admin',
        category: McpToolCategory.privileged,
      ),
      const {},
    );
    const intent = IntentSpec(
      id: 'x',
      allowedEffects: {ActionEffect.privilegedSystemOperation},
    );
    final outcome = pipeline.govern(
      intent,
      candidate,
      graph: graphWithShizukuUnavailable(),
    );
    expect(outcome, isA<GovernanceDenied>());
  });

  test('Shizuku capability tipada → channel shizuku, capability shizuku', () {
    final candidate = const ShizukuCapabilityProvider().capability(
      ShizukuCapability.installPackage,
      const {'packageName': 'com.x'},
    );
    expect(candidate.channel, ActionChannel.shizuku);
    expect(candidate.tool, 'install_package');
    expect(candidate.requiredCapabilities, contains(SystemCapability.shizuku));
  });

  test('Shizuku → denied (unavailable), nunca se ejecuta', () {
    final candidate = const ShizukuCapabilityProvider().capability(
      ShizukuCapability.forceStopPackage,
      const {'packageName': 'com.x'},
    );
    const intent = IntentSpec(
      id: 'x',
      allowedEffects: {ActionEffect.manageApplication},
    );
    final outcome = pipeline.govern(
      intent,
      candidate,
      graph: graphWithShizukuUnavailable(),
    );
    expect(outcome, isA<GovernanceDenied>());
  });

  test('no hay shell arbitrario: solo capacidades tipadas Shizuku', () {
    expect(ShizukuCapability.values, hasLength(4));
    expect(ShizukuCapability.values.map((c) => c.name), [
      'installPackage',
      'forceStopPackage',
      'grantSpecificPermission',
      'queryPackage',
    ]);
    // No existe executeShell/runRawShell en el contrato (estructural).
    expect(
      ShizukuCapability.values.any((c) => c.name.contains('shell')),
      isFalse,
    );
  });
}
