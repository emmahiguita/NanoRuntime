import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selector.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_set.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/koog_candidate_selector.dart';

class _FakeClient extends LLMEngineClient {
  _FakeClient(this.canned);
  final String canned;
  int calls = 0;

  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
  }) async {
    calls++;
    return LLMResult(text: canned);
  }
}

CandidateAction app(String id, String pkg) => CandidateAction(
  id: CandidateId(id),
  semanticAction: 'open_app',
  tool: 'launch_app',
  args: {'packageName': pkg},
  channel: ActionChannel.androidIntent,
  groundingConfidence: 0.5,
  risk: ToolRisk.device,
  reversible: true,
  evidence: [
    ActionEvidence(
      source: ActionEvidenceSource.packageManager,
      reference: pkg,
      confidence: 0.5,
    ),
  ],
);

CandidateSet ambiguousSet() => CandidateSet([
  app('app:launch:com.whatsapp', 'com.whatsapp'),
  app('app:launch:com.whatsapp.w4b', 'com.whatsapp.w4b'),
]);

CandidateSelectionRequest request(CandidateSet set) =>
    CandidateSelectionRequest(goal: 'abre Whats', candidates: set);

void main() {
  test('candidateId válido → SelectedCandidate', () async {
    final client = _FakeClient('{"candidateId":"app:launch:com.whatsapp"}');
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<SelectedCandidate>());
    expect(
      (sel as SelectedCandidate).candidate.id.value,
      'app:launch:com.whatsapp',
    );
    expect(client.calls, 1);
  });

  test('candidateId desconocido → InvalidCandidateSelection', () async {
    final client = _FakeClient('{"candidateId":"app:launch:evil.fake"}');
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<InvalidCandidateSelection>());
  });

  test('package fabricado → rechazado', () async {
    final client = _FakeClient('{"candidateId":"app:launch:com.fake.chrome"}');
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<InvalidCandidateSelection>());
  });

  test('ToolCall JSON (sin candidateId) → rechazado', () async {
    final client = _FakeClient(
      '{"tool":"launch_app","args":{"packageName":"com.whatsapp"}}',
    );
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<InvalidCandidateSelection>());
  });

  test('selector output → rechazado', () async {
    final client = _FakeClient('{"selector":"text=WhatsApp"}');
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<InvalidCandidateSelection>());
  });

  test('JSON malformado → rechazado', () async {
    final client = _FakeClient('no soy json');
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<InvalidCandidateSelection>());
  });

  test('candidateId no-string → rechazado', () async {
    final client = _FakeClient('{"candidateId":42}');
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<InvalidCandidateSelection>());
  });

  test('abstención (null) preserva ambigüedad', () async {
    final client = _FakeClient('{"candidateId":null}');
    final sel = await KoogCandidateSelector(
      client,
    ).select(request(ambiguousSet()));
    expect(sel, isA<AmbiguousCandidates>());
    expect((sel as AmbiguousCandidates).candidates, hasLength(2));
  });
}
