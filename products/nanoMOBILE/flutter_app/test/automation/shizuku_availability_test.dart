import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/governance/action_governance_pipeline.dart';
import 'package:nanoai/features/automation/engine/governance/intent_firewall.dart';
import 'package:nanoai/features/automation/engine/governance/intent_spec.dart';
import 'package:nanoai/features/automation/engine/governance/pre_action_critic.dart';
import 'package:nanoai/features/automation/engine/governance/privilege_broker.dart';
import 'package:nanoai/features/automation/engine/privilege/shizuku_availability.dart';
import 'package:nanoai/features/automation/engine/privilege/shizuku_capability.dart';

void main() {
  test('provider default → unsupported (no finge disponibilidad)', () async {
    const provider = UnsupportedShizukuAvailabilityProvider();
    final status = await provider.status();
    expect(status.status, ShizukuStatus.unsupported);
    expect(status.isAvailable, isFalse);
  });

  test('broker: shizuku null → unavailable', () {
    final cand = const ShizukuCapabilityProvider().capability(
      ShizukuCapability.queryPackage,
      const {},
    );
    final decision = const PrivilegeBroker().resolve(cand);
    expect(decision.tier, PrivilegeTier.shizuku);
    expect(decision.available, isFalse);
  });

  test('broker: shizuku available → disponible (governance aún necesario)', () {
    final cand = const ShizukuCapabilityProvider().capability(
      ShizukuCapability.queryPackage,
      const {},
    );
    final decision = const PrivilegeBroker().resolve(
      cand,
      shizuku: const ShizukuAvailability(ShizukuStatus.available, 'ok'),
    );
    expect(decision.tier, PrivilegeTier.shizuku);
    expect(decision.available, isTrue);
  });

  test(
    'capability != authority: shizuku available + navigate → firewall deny',
    () {
      final cand = const ShizukuCapabilityProvider().capability(
        ShizukuCapability.installPackage,
        const {'packageName': 'com.x'},
      );
      const intent = IntentSpec(
        id: 'x',
        allowedEffects: {ActionEffect.navigate},
      );
      const pipeline = ActionGovernancePipeline(
        firewall: IntentFirewall(),
        critic: PreActionCritic(),
        broker: PrivilegeBroker(),
      );
      // Aunque Shizuku esté disponible, installPackage no está en el IntentSpec.
      final outcome = pipeline.govern(
        intent,
        cand,
        shizuku: const ShizukuAvailability(ShizukuStatus.available, 'ok'),
      );
      expect(outcome, isA<GovernanceDenied>());
    },
  );

  test('status es pasivo: sin requestPermission en el contrato', () async {
    const provider = UnsupportedShizukuAvailabilityProvider();
    final status = await provider.status();
    expect(status.isAvailable, isFalse);
    // La interface ShizukuAvailabilityProvider solo expone status(); no existe
    // requestPermission → no puede pedir permiso automáticamente.
  });
}
