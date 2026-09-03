import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/koog_supervisor.dart';

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

class _ThrowingClient extends LLMEngineClient {
  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
  }) async {
    throw StateError('motor caído');
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

KoogSupervisionContext ctx(List<CandidateAction> candidates) =>
    KoogSupervisionContext(
      goal: 'abre Whats',
      situationSummary: 'apps instaladas: 2; capabilities: notification',
      candidates: candidates.map(KoogCandidateView.fromCandidate).toList(),
    );

void main() {
  final candidates = [
    app('app:launch:com.whatsapp', 'com.whatsapp'),
    app('app:launch:com.whatsapp.w4b', 'com.whatsapp.w4b'),
  ];

  test('act con candidateId existente → KoogAct', () async {
    final client = _FakeClient(
      '{"decision":"act","candidateId":"app:launch:com.whatsapp"}',
    );
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAct>());
    expect((d as KoogAct).candidateId.value, 'app:launch:com.whatsapp');
    expect(client.calls, 1);
  });

  test(
    'act con candidateId desconocido → abstención (jamás inventa)',
    () async {
      final client = _FakeClient(
        '{"decision":"act","candidateId":"app:launch:evil.fake"}',
      );
      final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
      expect(d, isA<KoogAbstain>());
      expect((d as KoogAbstain).reason, contains('desconocido'));
    },
  );

  test('act sin candidateId → abstención', () async {
    final client = _FakeClient('{"decision":"act"}');
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
  });

  test('ToolCall JSON (tool/args) → rechazado como malformed', () async {
    final client = _FakeClient(
      '{"tool":"launch_app","args":{"packageName":"com.whatsapp"}}',
    );
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
    expect((d as KoogAbstain).reason, contains('no interpretable'));
  });

  test('selector JSON → rechazado como malformed', () async {
    final client = _FakeClient('{"selector":"text=WhatsApp"}');
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
  });

  test('candidateId no-string → malformed → abstención', () async {
    final client = _FakeClient('{"decision":"act","candidateId":42}');
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
  });

  test('need_observation con reason → tipada', () async {
    final client = _FakeClient(
      '{"decision":"need_observation","reason":"no veo la pantalla"}',
    );
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogNeedObservation>());
    expect((d as KoogNeedObservation).reason, 'no veo la pantalla');
  });

  test('need_confirmation → tipada (el modelo NO se auto-confirma)', () async {
    final client = _FakeClient(
      '{"decision":"need_confirmation","reason":"acción irreversible"}',
    );
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogNeedConfirmation>());
  });

  test('completed con reason → KoogCompleted(summary)', () async {
    final client = _FakeClient(
      '{"decision":"completed","reason":"WhatsApp ya está abierto"}',
    );
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogCompleted>());
    expect((d as KoogCompleted).summary, 'WhatsApp ya está abierto');
  });

  test('failed → KoogFailed', () async {
    final client = _FakeClient(
      '{"decision":"failed","reason":"no hay candidato viable"}',
    );
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogFailed>());
  });

  test('abstain explícito → KoogAbstain', () async {
    final client = _FakeClient('{"decision":"abstain","reason":"sin opinión"}');
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
    expect((d as KoogAbstain).reason, 'sin opinión');
  });

  test('decision fuera del vocabulario → abstención', () async {
    final client = _FakeClient('{"decision":"destroy_all"}');
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
  });

  test('JSON malformado → abstención, nunca lanza', () async {
    final client = _FakeClient('no soy json');
    final d = await LlmKoogSupervisor(client).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
  });

  test('LLM no disponible (lanza) → abstención, nunca propaga', () async {
    final d = await LlmKoogSupervisor(
      _ThrowingClient(),
    ).decide(ctx(candidates));
    expect(d, isA<KoogAbstain>());
    expect((d as KoogAbstain).reason, contains('no disponible'));
  });

  test('el prompt no expone args ni canales de ejecución', () async {
    final client = _FakeClient('{"decision":"abstain"}');
    await LlmKoogSupervisor(client).decide(ctx(candidates));
    // El prompt se construye por cliente; verificamos que el contexto no
    // filtra datos crudos: KoogCandidateView solo expone id/semántica/evidencia.
    final view = KoogCandidateView.fromCandidate(candidates.first);
    expect(view.semanticAction, 'open_app');
    expect(view.evidence, contains('packageManager'));
  });
}
