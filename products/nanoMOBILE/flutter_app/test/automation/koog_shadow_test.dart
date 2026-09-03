import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/koog_shadow.dart';
import 'package:nanoai/features/automation/engine/planning/koog_supervisor.dart';

class _FakeSupervisor implements KoogSupervisor {
  _FakeSupervisor(this.canned);
  final KoogSupervisionDecision canned;
  int calls = 0;

  @override
  Future<KoogSupervisionDecision> decide(KoogSupervisionContext context) async {
    calls++;
    return canned;
  }
}

class _ThrowingSupervisor implements KoogSupervisor {
  @override
  Future<KoogSupervisionDecision> decide(KoogSupervisionContext context) async {
    throw StateError('boom');
  }
}

const ctx = KoogSupervisionContext(
  goal: 'abre Whats',
  situationSummary: 'apps instaladas: 2',
  candidates: [],
);

void main() {
  test('deshabilitado → no llama al supervisor (costo cero)', () async {
    final supervisor = _FakeSupervisor(const KoogAbstain('x'));
    final observer = KoogShadowObserver(supervisor: supervisor);
    expect(observer.enabled, isFalse);
    await observer.observe(
      context: ctx,
      authoritative: AuthoritativeOutcome.selectedCandidate,
      authoritativeCandidateId: 'app:launch:com.whatsapp',
    );
    expect(supervisor.calls, 0);
  });

  test('mismo candidato seleccionado → acuerdo, sin reporte', () async {
    final supervisor = _FakeSupervisor(
      KoogAct(CandidateId('app:launch:com.whatsapp')),
    );
    final reports = <KoogShadowDisagreement>[];
    final observer = KoogShadowObserver(
      supervisor: supervisor,
      onDisagreement: reports.add,
      enabled: true,
    );
    await observer.observe(
      context: ctx,
      authoritative: AuthoritativeOutcome.selectedCandidate,
      authoritativeCandidateId: 'app:launch:com.whatsapp',
    );
    expect(reports, isEmpty);
  });

  test('candidato distinto → desacuerdo reportado', () async {
    final supervisor = _FakeSupervisor(
      KoogAct(CandidateId('app:launch:com.whatsapp.w4b')),
    );
    final reports = <KoogShadowDisagreement>[];
    final observer = KoogShadowObserver(
      supervisor: supervisor,
      onDisagreement: reports.add,
      enabled: true,
    );
    await observer.observe(
      context: ctx,
      authoritative: AuthoritativeOutcome.selectedCandidate,
      authoritativeCandidateId: 'app:launch:com.whatsapp',
    );
    expect(reports, hasLength(1));
    expect(reports.single.contextGoal, 'abre Whats');
    expect(
      reports.single.authoritative,
      AuthoritativeOutcome.selectedCandidate,
    );
    expect(reports.single.authoritativeCandidateId, 'app:launch:com.whatsapp');
    expect(reports.single.koogDecision, isA<KoogAct>());
  });

  test('autoritativo noCandidate + KoogAct → desacuerdo', () async {
    final supervisor = _FakeSupervisor(
      KoogAct(CandidateId('app:launch:com.whatsapp')),
    );
    final reports = <KoogShadowDisagreement>[];
    final observer = KoogShadowObserver(
      supervisor: supervisor,
      onDisagreement: reports.add,
      enabled: true,
    );
    await observer.observe(
      context: ctx,
      authoritative: AuthoritativeOutcome.noCandidate,
    );
    expect(reports, hasLength(1));
  });

  test('autoritativo noCandidate + abstención → acuerdo', () async {
    final supervisor = _FakeSupervisor(const KoogAbstain('x'));
    final reports = <KoogShadowDisagreement>[];
    final observer = KoogShadowObserver(
      supervisor: supervisor,
      onDisagreement: reports.add,
      enabled: true,
    );
    await observer.observe(
      context: ctx,
      authoritative: AuthoritativeOutcome.noCandidate,
    );
    expect(reports, isEmpty);
  });

  test('autoritativo ambiguous + NeedConfirmation → acuerdo', () async {
    final supervisor = _FakeSupervisor(
      const KoogNeedConfirmation('acción irreversible'),
    );
    final reports = <KoogShadowDisagreement>[];
    final observer = KoogShadowObserver(
      supervisor: supervisor,
      onDisagreement: reports.add,
      enabled: true,
    );
    await observer.observe(
      context: ctx,
      authoritative: AuthoritativeOutcome.ambiguous,
    );
    expect(reports, isEmpty);
  });

  test(
    'selected + KoogCompleted → desacuerdo (el pipeline no emite eso)',
    () async {
      final supervisor = _FakeSupervisor(
        const KoogCompleted(summary: 'ya está'),
      );
      final reports = <KoogShadowDisagreement>[];
      final observer = KoogShadowObserver(
        supervisor: supervisor,
        onDisagreement: reports.add,
        enabled: true,
      );
      await observer.observe(
        context: ctx,
        authoritative: AuthoritativeOutcome.selectedCandidate,
        authoritativeCandidateId: 'app:launch:com.whatsapp',
      );
      expect(reports, hasLength(1));
    },
  );

  test('supervisor lanza → shadow silencioso, sin reporte ni crash', () async {
    final reports = <KoogShadowDisagreement>[];
    final observer = KoogShadowObserver(
      supervisor: _ThrowingSupervisor(),
      onDisagreement: reports.add,
      enabled: true,
    );
    await observer.observe(
      context: ctx,
      authoritative: AuthoritativeOutcome.selectedCandidate,
      authoritativeCandidateId: 'app:launch:com.whatsapp',
    );
    expect(reports, isEmpty);
  });
}
