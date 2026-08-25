import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_set.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';

/// Candidato grounded de ejemplo (package real del catálogo, no inventado).
CandidateAction launchChrome() => CandidateAction(
  id: CandidateId('app:launch:com.android.chrome'),
  semanticAction: 'open_app',
  tool: 'launch_app',
  args: const {'packageName': 'com.android.chrome'},
  channel: ActionChannel.androidIntent,
  groundingConfidence: 1.0,
  risk: ToolRisk.device,
  reversible: true,
  requiredCapabilities: const {SystemCapability.launchApps},
  evidence: [
    ActionEvidence(
      source: ActionEvidenceSource.packageManager,
      reference: 'com.android.chrome',
      confidence: 1.0,
    ),
  ],
);

void main() {
  group('CandidateId', () {
    test('rechaza vacío', () {
      expect(() => CandidateId(''), throwsArgumentError);
      expect(() => CandidateId('   '), throwsArgumentError);
    });

    test('equality estable y determinista', () {
      expect(CandidateId('app:launch:x'), CandidateId('app:launch:x'));
      expect(
        CandidateId('app:launch:x').hashCode,
        CandidateId('app:launch:x').hashCode,
      );
      expect(CandidateId('app:launch:x'), isNot(CandidateId('app:launch:y')));
      expect(CandidateId('a:b').toString(), 'a:b');
    });
  });

  group('CandidateAction invariantes', () {
    test('rechaza semanticAction vacío', () {
      expect(
        () => CandidateAction(
          id: CandidateId('x'),
          semanticAction: '  ',
          tool: 'launch_app',
          args: const {},
          channel: ActionChannel.androidIntent,
          groundingConfidence: 1.0,
          risk: ToolRisk.device,
          reversible: true,
          evidence: [
            ActionEvidence(
              source: ActionEvidenceSource.deterministicCatalog,
              reference: 'x',
              confidence: 1.0,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rechaza tool vacío', () {
      expect(
        () => CandidateAction(
          id: CandidateId('x'),
          semanticAction: 'open_app',
          tool: '',
          args: const {},
          channel: ActionChannel.androidIntent,
          groundingConfidence: 1.0,
          risk: ToolRisk.device,
          reversible: true,
          evidence: [
            ActionEvidence(
              source: ActionEvidenceSource.deterministicCatalog,
              reference: 'x',
              confidence: 1.0,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('groundingConfidence fuera de [0,1] rechazada', () {
      CandidateAction grounded() => launchChrome();
      expect(
        () => CandidateAction(
          id: CandidateId('x'),
          semanticAction: 'open_app',
          tool: 'launch_app',
          args: const {},
          channel: ActionChannel.androidIntent,
          groundingConfidence: -0.1,
          risk: ToolRisk.device,
          reversible: true,
          evidence: grounded().evidence,
        ),
        throwsArgumentError,
      );
      expect(
        () => CandidateAction(
          id: CandidateId('x'),
          semanticAction: 'open_app',
          tool: 'launch_app',
          args: const {},
          channel: ActionChannel.androidIntent,
          groundingConfidence: 1.1,
          risk: ToolRisk.device,
          reversible: true,
          evidence: grounded().evidence,
        ),
        throwsArgumentError,
      );
    });

    test('expectedSuccess fuera de [0,1] rechazada', () {
      expect(
        () => CandidateAction(
          id: CandidateId('x'),
          semanticAction: 'open_app',
          tool: 'launch_app',
          args: const {},
          channel: ActionChannel.androidIntent,
          groundingConfidence: 1.0,
          expectedSuccess: 2.0,
          risk: ToolRisk.device,
          reversible: true,
          evidence: launchChrome().evidence,
        ),
        throwsArgumentError,
      );
    });

    test('requiere evidence (grounded)', () {
      expect(
        () => CandidateAction(
          id: CandidateId('x'),
          semanticAction: 'open_app',
          tool: 'launch_app',
          args: const {},
          channel: ActionChannel.androidIntent,
          groundingConfidence: 1.0,
          risk: ToolRisk.device,
          reversible: true,
          evidence: const [],
        ),
        throwsArgumentError,
      );
    });

    test('candidato determinista válido se construye', () {
      final c = launchChrome();
      expect(c.id.value, 'app:launch:com.android.chrome');
      expect(c.semanticAction, 'open_app');
      expect(c.tool, 'launch_app');
      expect(c.args['packageName'], 'com.android.chrome');
      expect(c.groundingConfidence, 1.0);
      expect(c.reversible, isTrue);
    });

    test('candidato PackageManager con evidence real se construye', () {
      final c = launchChrome();
      expect(c.evidence.single.source, ActionEvidenceSource.packageManager);
      expect(c.evidence.single.reference, 'com.android.chrome');
      expect(c.requiredCapabilities, contains(SystemCapability.launchApps));
    });

    test('args inmutable', () {
      final c = launchChrome();
      expect(() => c.args['packageName'] = 'x', throwsUnsupportedError);
    });

    test('evidence inmutable', () {
      final c = launchChrome();
      expect(
        () => c.evidence.add(launchChrome().evidence.single),
        throwsUnsupportedError,
      );
    });

    test('requiredCapabilities inmutable', () {
      final c = launchChrome();
      expect(
        () => c.requiredCapabilities.add(SystemCapability.root),
        throwsUnsupportedError,
      );
    });
  });

  group('CandidateSet', () {
    test('rechaza IDs duplicados', () {
      expect(
        () => CandidateSet([launchChrome(), launchChrome()]),
        throwsArgumentError,
      );
    });

    test('lookup por id funciona', () {
      final set = CandidateSet([launchChrome()]);
      expect(set.length, 1);
      expect(set.byId(CandidateId('app:launch:com.android.chrome')), isNotNull);
      expect(set.byId(CandidateId('no-existe')), isNull);
    });

    test('vacío funciona', () {
      final set = CandidateSet([]);
      expect(set.isEmpty, isTrue);
      expect(set.length, 0);
    });
  });

  group('CandidateSelection', () {
    test('SelectedCandidate', () {
      final s = SelectedCandidate(launchChrome());
      expect(s.candidate.id.value, 'app:launch:com.android.chrome');
    });

    test('AmbiguousCandidates con razón tipada', () {
      final s = AmbiguousCandidates([launchChrome()], 'dos matches');
      expect(s.candidates, hasLength(1));
      expect(s.reason, 'dos matches');
      expect(() => s.candidates.add(launchChrome()), throwsUnsupportedError);
    });

    test('NoCandidate', () {
      const s = NoCandidate('sin fuente');
      expect(s.reason, 'sin fuente');
    });
  });
}
