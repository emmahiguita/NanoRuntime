import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/governance/action_governance_pipeline.dart';
import 'package:nanoai/features/automation/engine/governance/intent_firewall.dart';
import 'package:nanoai/features/automation/engine/governance/intent_spec.dart';
import 'package:nanoai/features/automation/engine/governance/intent_spec_compiler.dart';
import 'package:nanoai/features/automation/engine/governance/pre_action_critic.dart';
import 'package:nanoai/features/automation/engine/governance/privilege_broker.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/system/capability_availability.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_graph.dart';
import 'package:nanoai/features/automation/engine/system/system_models.dart';

CandidateAction candidate({
  required String id,
  required String tool,
  Map<String, Object?> args = const {},
  ActionChannel channel = ActionChannel.androidIntent,
  double grounding = 1.0,
  bool reversible = true,
  Set<SystemCapability> caps = const {},
}) => CandidateAction(
  id: CandidateId(id),
  semanticAction: 'act',
  tool: tool,
  args: args,
  channel: channel,
  groundingConfidence: grounding,
  risk: ToolRisk.device,
  reversible: reversible,
  requiredCapabilities: caps,
  evidence: [
    ActionEvidence(
      source: ActionEvidenceSource.deterministicCatalog,
      reference: id,
      confidence: grounding,
    ),
  ],
);

SystemGraph graphWith(Set<SystemCapability> available) => SystemGraph(
  device: const DeviceProfile(
    manufacturer: '',
    model: '',
    sdkInt: 0,
    release: '',
  ),
  apps: const [],
  roles: const [],
  capabilities: {
    for (final c in available)
      c: CapabilityAvailability(
        capability: c,
        state: CapabilityAvailabilityKind.available,
        reason: 'test',
      ),
  },
);

void main() {
  group('IntentSpecCompiler', () {
    test('abre Bluetooth → navigate (no state mutation)', () {
      final spec = const IntentSpecCompiler().compile('abre Bluetooth');
      expect(spec.allows(ActionEffect.navigate), isTrue);
      expect(spec.allows(ActionEffect.changeSystemState), isFalse);
    });

    test('activa Bluetooth → changeSystemState', () {
      final spec = const IntentSpecCompiler().compile('activa Bluetooth');
      expect(spec.allows(ActionEffect.changeSystemState), isTrue);
    });

    test('lee notificaciones → read (no send)', () {
      final spec = const IntentSpecCompiler().compile('lee notificaciones');
      expect(spec.allows(ActionEffect.read), isTrue);
      expect(spec.allows(ActionEffect.sendExternalMessage), isFalse);
    });

    test('responde a Juan → send con target juan', () {
      final spec = const IntentSpecCompiler().compile(
        'responde a Juan que llego',
      );
      expect(spec.allows(ActionEffect.sendExternalMessage), isTrue);
      expect(spec.targetScope, 'juan');
    });
  });

  group('IntentFirewall', () {
    const firewall = IntentFirewall();

    test('navegación dentro del intent → allowed', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      final cand = candidate(
        id: 'a',
        tool: 'open_system',
        args: const {'destination': 'bluetooth_settings'},
      );
      expect(firewall.check(intent, cand), isA<FirewallAllowed>());
    });

    test('send message fuera de navigate → denied', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      final cand = candidate(id: 'a', tool: 'reply_notification');
      expect(firewall.check(intent, cand), isA<FirewallDenied>());
    });

    test('target mismatch (Juan vs Pedro) → denied', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.sendExternalMessage},
        targetScope: 'juan',
      );
      final cand = candidate(
        id: 'a',
        tool: 'reply_notification',
        args: const {'target': 'pedro'},
      );
      expect(firewall.check(intent, cand), isA<FirewallDenied>());
    });

    test('contenido observado no amplía scope (navigate no permite send)', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      final cand = candidate(id: 'a', tool: 'reply_notification');
      expect(firewall.check(intent, cand), isA<FirewallDenied>());
    });
  });

  group('PreActionCritic', () {
    const critic = PreActionCritic();

    test('grounded reversible navigate → approve', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      final cand = candidate(
        id: 'a',
        tool: 'open_system',
        args: const {'destination': 'settings'},
      );
      expect(critic.review(intent, cand), isA<ApprovedAction>());
    });

    test('grounding insuficiente (evidencia inferida) → more evidence', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.writeUi},
      );
      final cand = CandidateAction(
        id: CandidateId('a'),
        semanticAction: 'act',
        tool: 'tap',
        args: const {},
        channel: ActionChannel.vision,
        groundingConfidence: 0.3,
        risk: ToolRisk.device,
        reversible: true,
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.vision,
            reference: 'a',
            confidence: 0.3,
          ),
        ],
      );
      expect(critic.review(intent, cand), isA<MoreEvidenceRequiredAction>());
    });

    test('external irreversible → confirmation', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.sendExternalMessage},
      );
      final cand = candidate(
        id: 'a',
        tool: 'reply_notification',
        reversible: false,
      );
      expect(critic.review(intent, cand), isA<ConfirmationRequiredAction>());
    });

    test('capability unavailable → rejected', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.writeUi},
      );
      final cand = candidate(
        id: 'a',
        tool: 'tap',
        channel: ActionChannel.accessibility,
        caps: const {SystemCapability.interactAccessibility},
      );
      const graph = SystemGraph(
        device: DeviceProfile(
          manufacturer: '',
          model: '',
          sdkInt: 0,
          release: '',
        ),
        apps: [],
        roles: [],
        capabilities: {
          SystemCapability.interactAccessibility: CapabilityAvailability(
            capability: SystemCapability.interactAccessibility,
            state: CapabilityAvailabilityKind.requiresAccessibility,
            reason: 'test',
          ),
        },
      );
      final d = critic.review(intent, cand, graph: graph);
      expect(d, isA<RejectedAction>());
      expect((d as RejectedAction).reason, GovernanceReason.requiresEnablement);
    });
  });

  group('PrivilegeBroker', () {
    const broker = PrivilegeBroker();

    test('public Intent → publicAndroid', () {
      final cand = candidate(id: 'a', tool: 'open_system');
      expect(broker.resolve(cand).tier, PrivilegeTier.publicAndroid);
    });

    test('accessibility action → accessibility tier', () {
      final cand = candidate(
        id: 'a',
        tool: 'tap',
        channel: ActionChannel.accessibility,
        caps: const {SystemCapability.interactAccessibility},
      );
      expect(broker.resolve(cand).tier, PrivilegeTier.accessibility);
    });

    test('notification → notificationAccess tier', () {
      final cand = candidate(id: 'a', tool: 'reply_notification');
      expect(broker.resolve(cand).tier, PrivilegeTier.notificationAccess);
    });

    test('shizuku/root tiers → no disponibles en A11', () {
      // Ningún tool actual mapea a shizuku/root; el broker nunca las devuelve
      // disponibles sin SystemGraph evidence. Se prueban como unavailable.
      final graph = graphWith(const {});
      final cand = candidate(
        id: 'a',
        tool: 'tap',
        caps: const {SystemCapability.shizuku},
      );
      expect(broker.resolve(cand, graph: graph).available, isFalse);
    });
  });

  group('ActionGovernancePipeline', () {
    const pipeline = ActionGovernancePipeline(
      firewall: IntentFirewall(),
      critic: PreActionCritic(),
      broker: PrivilegeBroker(),
    );

    test('candidato válido dentro del intent → approved', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      final cand = candidate(
        id: 'a',
        tool: 'open_system',
        args: const {'destination': 'settings'},
      );
      expect(pipeline.govern(intent, cand), isA<GovernanceApproved>());
    });

    test('Koog selecciona candidato fuera del intent → denied', () {
      // Koog solo elige candidateId existente, pero el firewall lo deniega si
      // está fuera del IntentSpec.
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      final cand = candidate(
        id: 'a',
        tool: 'reply_notification',
        args: const {'target': 'juan'},
      );
      expect(pipeline.govern(intent, cand), isA<GovernanceDenied>());
    });

    test('NanoFlow verificado no omite el scope actual', () {
      // Un flow aprendido puede contener acciones más amplias que el request.
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      final deleteStep = candidate(
        id: 'a',
        tool: 'linux.writeFile',
        args: const {'path': '/tmp/x'},
      );
      expect(pipeline.govern(intent, deleteStep), isA<GovernanceDenied>());
    });

    test('privilegio no disponible → denied', () {
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.writeUi},
      );
      final cand = candidate(
        id: 'a',
        tool: 'tap',
        channel: ActionChannel.accessibility,
        caps: const {SystemCapability.interactAccessibility},
      );
      final graph = graphWith(const {});
      final out = pipeline.govern(intent, cand, graph: graph);
      expect(out, isA<GovernanceDenied>());
    });
  });
}
