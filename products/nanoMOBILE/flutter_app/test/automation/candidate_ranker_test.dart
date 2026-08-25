import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/action_verifier.dart'
    show ActionExpectation;
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_ranker.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_set.dart';

CandidateAction make({
  required String id,
  required String semanticAction,
  required String tool,
  Map<String, Object?> args = const {},
  ActionChannel channel = ActionChannel.androidIntent,
  double grounding = 1.0,
  ActionExpectation? expectation,
}) => CandidateAction(
  id: CandidateId(id),
  semanticAction: semanticAction,
  tool: tool,
  args: args,
  channel: channel,
  groundingConfidence: grounding,
  risk: ToolRisk.device,
  reversible: true,
  evidence: [
    ActionEvidence(
      source: ActionEvidenceSource.deterministicCatalog,
      reference: id,
      confidence: grounding,
    ),
  ],
  expectation: expectation,
);

void main() {
  test('nanoFlow rankea por encima de androidIntent (mismo payload)', () {
    final nano = make(
      id: 'nanoflow:x',
      semanticAction: 'open_app',
      tool: 'launch_app',
      args: const {'packageName': 'com.android.chrome'},
      channel: ActionChannel.nanoFlow,
      expectation: const ActionExpectation(
        expectedPackage: 'com.android.chrome',
      ),
    );
    final installed = make(
      id: 'app:launch:com.android.chrome',
      semanticAction: 'open_app',
      tool: 'launch_app',
      args: const {'packageName': 'com.android.chrome'},
      channel: ActionChannel.androidIntent,
      expectation: const ActionExpectation(
        expectedPackage: 'com.android.chrome',
      ),
    );

    final sel = CandidateRanker().rank(CandidateSet([installed, nano]));
    expect(sel, isA<SelectedCandidate>());
    expect(
      (sel as SelectedCandidate).candidate.channel,
      ActionChannel.nanoFlow,
    );
  });

  test('androidIntent rankea por encima de accessibility (mismo target)', () {
    final intent = make(
      id: 'system:intent:bluetooth_settings',
      semanticAction: 'open_bluetooth_settings',
      tool: 'open_system',
      args: const {'destination': 'bluetooth_settings'},
      channel: ActionChannel.androidIntent,
    );
    final acc = make(
      id: 'accessibility:bt',
      semanticAction: 'open_bluetooth_settings',
      tool: 'open_system',
      args: const {'destination': 'bluetooth_settings'},
      channel: ActionChannel.accessibility,
    );

    final sel = CandidateRanker().rank(CandidateSet([acc, intent]));
    expect(
      (sel as SelectedCandidate).candidate.channel,
      ActionChannel.androidIntent,
    );
  });

  test('ambiguo cuando margen insuficiente y targets distintos', () {
    final a = make(
      id: 'app:launch:com.whatsapp',
      semanticAction: 'open_app',
      tool: 'launch_app',
      args: const {'packageName': 'com.whatsapp'},
    );
    final b = make(
      id: 'app:launch:com.whatsapp.w4b',
      semanticAction: 'open_app',
      tool: 'launch_app',
      args: const {'packageName': 'com.whatsapp.w4b'},
    );

    final sel = CandidateRanker().rank(CandidateSet([a, b]));
    expect(sel, isA<AmbiguousCandidates>());
  });

  test('NoCandidate en set vacío', () {
    expect(CandidateRanker().rank(CandidateSet([])), isA<NoCandidate>());
  });

  test('puro y determinista: mismo input → mismo output', () {
    final a = make(
      id: 'a',
      semanticAction: 'open_app',
      tool: 'launch_app',
      args: const {'packageName': 'com.android.chrome'},
      channel: ActionChannel.nanoFlow,
    );
    final set = CandidateSet([a]);
    final ranker = CandidateRanker();
    final r1 = ranker.rank(set);
    final r2 = ranker.rank(set);
    expect(
      (r1 as SelectedCandidate).candidate.id,
      (r2 as SelectedCandidate).candidate.id,
    );
  });
}
