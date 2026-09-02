import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart'
    show ToolRisk;
import 'package:nanoai/features/automation/engine/memory/experience_cache.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_generator.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_provider.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_providers.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_ranker.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_tool_call_adapter.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_intent_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_models.dart'
    show InstalledApp;

import 'candidate_test_support.dart';

/// Pipeline completo con providers reales + fakes factuales.
(CandidateActionGenerator, CandidateRanker, CandidateToolCallAdapter) pipeline({
  ExperienceCache? cache,
  List<InstalledApp>? apps,
  Set<SystemCapability> capabilities = const {
    SystemCapability.openBluetoothSettings,
    SystemCapability.openWifiSettings,
    SystemCapability.openSystemSettings,
    SystemCapability.launchApps,
  },
}) {
  final catalog = catalogWith(apps ?? []);
  final generator = CandidateActionGenerator([
    NanoFlowCandidateProvider(cache ?? ExperienceCache()),
    SystemIntentCandidateProvider(
      defaultDeterministicCatalog,
      graphWith(capabilities),
      SystemIntentCatalog.builtin,
    ),
    InstalledAppCandidateProvider(catalog),
    DeterministicCandidateProvider(defaultDeterministicCatalog),
  ]);
  return (generator, CandidateRanker(), CandidateToolCallAdapter());
}

void main() {
  test('end-to-end: "abre Chrome" → launch_app grounded (0 LLM)', () async {
    final (gen, ranker, adapter) = pipeline(
      apps: [app('Chrome', 'com.android.chrome')],
    );
    final result = await gen.generate(const CandidateRequest('abre Chrome'));
    expect(result.failures, isEmpty);
    expect(result.candidates.length, 1);

    final sel = ranker.rank(result.candidates);
    expect(sel, isA<SelectedCandidate>());
    final tc = adapter.toToolCall((sel as SelectedCandidate).candidate);
    expect(tc.tool, 'launch_app');
    expect(tc.args!['packageName'], 'com.android.chrome');
    expect(tc.selector, isNull);
    expect(tc.text, isNull);
    expect(tc.key, isNull);
  });

  test(
    'end-to-end: "abre Bluetooth" → open_system (0 LLM, sin selector UI)',
    () async {
      final (gen, ranker, adapter) = pipeline();
      final result = await gen.generate(
        const CandidateRequest('abre Bluetooth'),
      );
      expect(result.candidates.length, 1);

      final tc = adapter.toToolCall(
        (ranker.rank(result.candidates) as SelectedCandidate).candidate,
      );
      expect(tc.tool, 'open_system');
      expect(tc.args!['destination'], 'bluetooth_settings');
      expect(tc.selector, isNull);
    },
  );

  test(
    'end-to-end: "abre com.fake.chrome" → NoCandidate (sin package fabricado)',
    () async {
      final (gen, ranker, _) = pipeline(
        apps: [app('Chrome', 'com.android.chrome')],
      );
      final result = await gen.generate(
        const CandidateRequest('abre com.fake.chrome'),
      );
      expect(result.candidates.isEmpty, isTrue);
      expect(ranker.rank(result.candidates), isA<NoCandidate>());
    },
  );

  test('end-to-end: "abre Whats" ambiguo → sin ToolCall', () async {
    final (gen, ranker, _) = pipeline(
      apps: [
        app('WhatsApp', 'com.whatsapp'),
        app('WhatsApp Business', 'com.whatsapp.w4b'),
      ],
    );
    final result = await gen.generate(const CandidateRequest('abre Whats'));
    final sel = ranker.rank(result.candidates);
    expect(sel, isA<AmbiguousCandidates>());
  });

  test('end-to-end: flow verificado nanoFlow rankea por encima', () async {
    final cache = ExperienceCache();
    cache.recordSuccess('abre Chrome', [
      const ToolCall(
        tool: 'launch_app',
        args: {'packageName': 'com.android.chrome'},
      ),
    ]);
    final (gen, ranker, _) = pipeline(
      cache: cache,
      apps: [app('Chrome', 'com.android.chrome')],
    );
    final result = await gen.generate(const CandidateRequest('abre Chrome'));
    expect(result.candidates.length, 2); // nanoFlow + installedApp

    final sel = ranker.rank(result.candidates);
    expect(
      (sel as SelectedCandidate).candidate.channel,
      ActionChannel.nanoFlow,
    );
  });

  test('security: tool desconocido → adapter rechaza', () async {
    final (gen, ranker, adapter) = pipeline();
    // Construye un candidato con tool inexistente (fuera del registry).
    final result = await gen.generate(const CandidateRequest('volver'));
    final sel = ranker.rank(result.candidates);
    final candidate = (sel as SelectedCandidate).candidate;
    // El tool 'back' existe; verificamos el rechazo con un candidato artificial.
    final forged = CandidateAction(
      id: CandidateId('forged'),
      semanticAction: 'x',
      tool: 'hack_device',
      args: const {},
      channel: ActionChannel.deterministic,
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
    );
    expect(
      () => adapter.toToolCall(forged),
      throwsA(isA<CandidateToolUnknown>()),
    );
    expect(candidate.tool, isNot('hack_device'));
  });
}
