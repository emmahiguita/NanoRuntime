import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_ranker.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection_engine.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selector.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_set.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/koog_candidate_selector.dart';

class _FakeKoog implements CandidateSelector {
  _FakeKoog(this.canned);
  final String canned;
  int calls = 0;

  @override
  Future<CandidateSelection> select(CandidateSelectionRequest request) async {
    calls++;
    return KoogCandidateSelector(_Client(canned)).select(request);
  }
}

class _Client extends LLMEngineClient {
  _Client(this.canned);
  final String canned;

  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
  }) async => LLMResult(text: canned);
}

CandidateAction app({
  required String id,
  required String pkg,
  ActionChannel channel = ActionChannel.androidIntent,
  double grounding = 0.5,
}) => CandidateAction(
  id: CandidateId(id),
  semanticAction: 'open_app',
  tool: 'launch_app',
  args: {'packageName': pkg},
  channel: channel,
  groundingConfidence: grounding,
  risk: ToolRisk.device,
  reversible: true,
  evidence: [
    ActionEvidence(
      source: ActionEvidenceSource.packageManager,
      reference: pkg,
      confidence: grounding,
    ),
  ],
);

void main() {
  test('ganador claro no invoca Koog (0 LLM)', () async {
    final koog = _FakeKoog('{"candidateId":"x"}');
    final engine = CandidateSelectionEngine(
      ranker: CandidateRanker(),
      koogSelector: koog,
    );
    final set = CandidateSet([
      app(
        id: 'app:launch:com.android.chrome',
        pkg: 'com.android.chrome',
        channel: ActionChannel.nanoFlow,
        grounding: 1.0,
      ),
    ]);
    final sel = await engine.select(
      CandidateSelectionRequest(goal: 'abre Chrome', candidates: set),
    );
    expect(sel, isA<SelectedCandidate>());
    expect(koog.calls, 0);
  });

  test('NoCandidate no invoca Koog (0 LLM)', () async {
    final koog = _FakeKoog('{"candidateId":"x"}');
    final engine = CandidateSelectionEngine(
      ranker: CandidateRanker(),
      koogSelector: koog,
    );
    final sel = await engine.select(
      CandidateSelectionRequest(goal: 'x', candidates: CandidateSet([])),
    );
    expect(sel, isA<NoCandidate>());
    expect(koog.calls, 0);
  });

  test('ambiguo invoca Koog una vez y resuelve', () async {
    final koog = _FakeKoog('{"candidateId":"app:launch:com.whatsapp"}');
    final engine = CandidateSelectionEngine(
      ranker: CandidateRanker(),
      koogSelector: koog,
    );
    final set = CandidateSet([
      app(id: 'app:launch:com.whatsapp', pkg: 'com.whatsapp'),
      app(id: 'app:launch:com.whatsapp.w4b', pkg: 'com.whatsapp.w4b'),
    ]);
    final sel = await engine.select(
      CandidateSelectionRequest(goal: 'abre Whats', candidates: set),
    );
    expect(sel, isA<SelectedCandidate>());
    expect(
      (sel as SelectedCandidate).candidate.id.value,
      'app:launch:com.whatsapp',
    );
    expect(koog.calls, 1);
  });

  test('sin selector → preserva ambigüedad', () async {
    final engine = CandidateSelectionEngine(ranker: CandidateRanker());
    final set = CandidateSet([
      app(id: 'app:launch:com.whatsapp', pkg: 'com.whatsapp'),
      app(id: 'app:launch:com.whatsapp.w4b', pkg: 'com.whatsapp.w4b'),
    ]);
    final sel = await engine.select(
      CandidateSelectionRequest(goal: 'abre Whats', candidates: set),
    );
    expect(sel, isA<AmbiguousCandidates>());
  });

  test('determinista sin Koog: mismo input → mismo output', () async {
    final engine = CandidateSelectionEngine(ranker: CandidateRanker());
    final set = CandidateSet([
      app(
        id: 'app:launch:com.android.chrome',
        pkg: 'com.android.chrome',
        channel: ActionChannel.nanoFlow,
        grounding: 1.0,
      ),
    ]);
    final r1 = await engine.select(
      CandidateSelectionRequest(goal: 'abre Chrome', candidates: set),
    );
    final r2 = await engine.select(
      CandidateSelectionRequest(goal: 'abre Chrome', candidates: set),
    );
    expect(
      (r1 as SelectedCandidate).candidate.id,
      (r2 as SelectedCandidate).candidate.id,
    );
  });
}
