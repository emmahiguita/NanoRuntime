import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/agents/agent_role.dart';
import 'package:nanoai/features/automation/engine/agents/agent_types.dart';
import 'package:nanoai/features/automation/engine/agents/nano_agent_orchestrator.dart';
import 'package:nanoai/features/automation/engine/governance/action_governance_pipeline.dart';
import 'package:nanoai/features/automation/engine/governance/intent_firewall.dart';
import 'package:nanoai/features/automation/engine/governance/intent_spec.dart';
import 'package:nanoai/features/automation/engine/governance/pre_action_critic.dart';
import 'package:nanoai/features/automation/engine/governance/privilege_broker.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_generator.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_providers.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_ranker.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection_engine.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';
import 'package:nanoai/features/automation/engine/skills/nano_skill.dart';
import 'package:nanoai/features/automation/engine/skills/nano_skills.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_intent_catalog.dart';

import 'candidate_test_support.dart';

void main() {
  group('Skills', () {
    test('OpenAppSkill produce launch_app grounded', () async {
      final skill = OpenAppSkill(
        catalogWith([app('Chrome', 'com.android.chrome')]),
      );
      expect(await skill.canHandle(const SkillContext('abre Chrome')), isTrue);
      final candidates = await skill.candidates(
        const SkillContext('abre Chrome'),
      );
      expect(candidates, hasLength(1));
      expect(candidates.single.tool, 'launch_app');
      expect(candidates.single.args['packageName'], 'com.android.chrome');
    });

    test('SystemNavigationSkill produce open_system grounded', () async {
      final skill = SystemNavigationSkill(
        defaultDeterministicCatalog,
        graphWith(const {SystemCapability.openBluetoothSettings}),
        SystemIntentCatalog.builtin,
      );
      expect(
        await skill.canHandle(const SkillContext('abre Bluetooth')),
        isTrue,
      );
      final candidates = await skill.candidates(
        const SkillContext('abre Bluetooth'),
      );
      expect(candidates.single.tool, 'open_system');
      expect(candidates.single.args['destination'], 'bluetooth_settings');
    });

    test('ReadNotificationsSkill produce notifications (read)', () async {
      final skill = ReadNotificationsSkill(defaultDeterministicCatalog);
      expect(
        await skill.canHandle(const SkillContext('lee notificaciones')),
        isTrue,
      );
      final candidates = await skill.candidates(
        const SkillContext('lee notificaciones'),
      );
      expect(candidates.single.tool, 'notifications');
    });

    test('skill no aplica → canHandle false', () async {
      final skill = OpenAppSkill(
        catalogWith([app('Chrome', 'com.android.chrome')]),
      );
      expect(
        await skill.canHandle(const SkillContext('activa Bluetooth')),
        isFalse,
      );
    });
  });

  group('NanoAgentOrchestrator', () {
    test('run "abre Chrome" → executor con candidate launch_app', () async {
      final orchestrator = NanoAgentOrchestrator(
        generator: CandidateActionGenerator([
          InstalledAppCandidateProvider(
            catalogWith([app('Chrome', 'com.android.chrome')]),
          ),
        ]),
        selection: CandidateSelectionEngine(ranker: CandidateRanker()),
        governance: const ActionGovernancePipeline(
          firewall: IntentFirewall(),
          critic: PreActionCritic(),
          broker: PrivilegeBroker(),
        ),
      );
      final result = await orchestrator.run(
        const AgentContext(goal: 'abre Chrome'),
      );
      expect(result.role, AgentRole.executor);
      expect(result.value, isA<CandidateAction>());
      expect((result.value as CandidateAction).tool, 'launch_app');
    });

    test('intent restrictivo → critic denial (governance)', () async {
      final orchestrator = NanoAgentOrchestrator(
        generator: CandidateActionGenerator([
          InstalledAppCandidateProvider(
            catalogWith([app('Chrome', 'com.android.chrome')]),
          ),
        ]),
        selection: CandidateSelectionEngine(ranker: CandidateRanker()),
        governance: const ActionGovernancePipeline(
          firewall: IntentFirewall(),
          critic: PreActionCritic(),
          broker: PrivilegeBroker(),
        ),
      );
      // Intent restrictivo (changeSystemState) no permite navigate (launch_app).
      final result = await orchestrator.run(
        const AgentContext(
          goal: 'abre Chrome',
          intent: IntentSpec(
            id: 'x',
            allowedEffects: {ActionEffect.changeSystemState},
          ),
        ),
      );
      expect(result.role, AgentRole.critic);
      expect(result.value, isA<GovernanceDenied>());
    });

    test('sin candidatos → planner (no ejecuta)', () async {
      final orchestrator = NanoAgentOrchestrator(
        generator: CandidateActionGenerator([
          InstalledAppCandidateProvider(catalogWith(const [])),
        ]),
        selection: CandidateSelectionEngine(ranker: CandidateRanker()),
        governance: const ActionGovernancePipeline(
          firewall: IntentFirewall(),
          critic: PreActionCritic(),
          broker: PrivilegeBroker(),
        ),
      );
      final result = await orchestrator.run(
        const AgentContext(goal: 'abre nada'),
      );
      expect(result.role, AgentRole.planner);
      expect(result.value, isNull);
    });
  });
}
