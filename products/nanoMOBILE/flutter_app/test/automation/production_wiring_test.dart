import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/governance/action_governance_pipeline.dart';
import 'package:nanoai/features/automation/engine/governance/intent_firewall.dart';
import 'package:nanoai/features/automation/engine/governance/pre_action_critic.dart';
import 'package:nanoai/features/automation/engine/governance/privilege_broker.dart';
import 'package:nanoai/features/automation/engine/planning/candidate_first_planner.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_generator.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_provider.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_providers.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_ranker.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selection_engine.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_selector.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_tool_call_adapter.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/koog_candidate_selector.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';
import 'package:nanoai/features/automation/engine/system/capability_availability.dart';
import 'package:nanoai/features/automation/engine/system/system_capability.dart';
import 'package:nanoai/features/automation/engine/system/system_graph.dart';
import 'package:nanoai/features/automation/engine/system/system_intent_catalog.dart';
import 'package:nanoai/features/automation/engine/system/system_models.dart';

import 'candidate_test_support.dart';

class _FakeDispatcher extends AgentToolDispatcher {
  final List<ToolCall> calls = [];

  @override
  Future<ToolOutcome> runToolGuarded(
    ToolCall call, {
    bool humanInitiated = false,
    bool confirmed = false,
  }) async {
    calls.add(call);
    return const ToolOutcome(verdict: PolicyVerdict.allow, feedback: 'ok');
  }
}

class _FakeReplyProvider implements CandidateProvider {
  @override
  String get id => 'fakeReply';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async => [
    CandidateAction(
      id: CandidateId('reply:juan'),
      semanticAction: 'reply_message',
      tool: 'reply_notification',
      args: const {'target': 'juan', 'text': 'ok'},
      channel: ActionChannel.notification,
      groundingConfidence: 1.0,
      risk: ToolRisk.externalWrite,
      reversible: false,
      evidence: [
        ActionEvidence(
          source: ActionEvidenceSource.notificationCapability,
          reference: 'juan',
          confidence: 1.0,
        ),
      ],
    ),
  ];
}

SystemGraph intentGraph() => SystemGraph(
  device: const DeviceProfile(
    manufacturer: '',
    model: '',
    sdkInt: 0,
    release: '',
  ),
  apps: const [],
  roles: const [],
  capabilities: {
    for (final c in const [
      SystemCapability.openSystemSettings,
      SystemCapability.openWifiSettings,
      SystemCapability.openBluetoothSettings,
      SystemCapability.launchApps,
      SystemCapability.interactAccessibility,
    ])
      c: CapabilityAvailability(
        capability: c,
        state: CapabilityAvailabilityKind.available,
        reason: 'allowlist',
      ),
  },
);

CandidateFirstPlanner planner(
  List<CandidateProvider> providers, {
  CandidateSelector? koogSelector,
}) => CandidateFirstPlanner(
  generatorBuilder: (graph) => CandidateActionGenerator(providers),
  selection: CandidateSelectionEngine(
    ranker: CandidateRanker(),
    koogSelector: koogSelector,
  ),
  governance: const ActionGovernancePipeline(
    firewall: IntentFirewall(),
    critic: PreActionCritic(),
    broker: PrivilegeBroker(),
  ),
  adapter: CandidateToolCallAdapter(),
  getGraph: () async => intentGraph(),
);

class _FakeKoogClient extends LLMEngineClient {
  _FakeKoogClient(this.canned);
  final String canned;

  @override
  Future<LLMResult> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 256,
  }) async => LLMResult(text: canned);
}

AutomationCoordinator coordinator(CandidateFirstPlanner candidateFirst) =>
    AutomationCoordinator(
      dispatcher: _FakeDispatcher(),
      mode: () => AgentAutomationMode.autonomous,
      candidateFirst: candidateFirst,
      verifyGoal: (goal, {required planCompleted, expectation}) async =>
          const GoalVerification(GoalStatus.satisfied, 'verified'),
    );

void main() {
  test('"abre Chrome" → Candidate-First → launch_app, 0 LLM', () async {
    final dispatcher = _FakeDispatcher();
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      candidateFirst: planner([
        InstalledAppCandidateProvider(
          catalogWith([app('Chrome', 'com.android.chrome')]),
        ),
      ]),
      verifyGoal: (goal, {required planCompleted, expectation}) async =>
          const GoalVerification(GoalStatus.satisfied, 'verified'),
    );
    final r = await c.execute(const AutomationGoal(text: 'abre Chrome'));
    expect(r.status, AutomationResultStatus.completed);
    expect(dispatcher.calls.single.tool, 'launch_app');
    expect(dispatcher.calls.single.args!['packageName'], 'com.android.chrome');
  });

  test('"abre Bluetooth" → Candidate-First → open_system, 0 LLM', () async {
    final dispatcher = _FakeDispatcher();
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      candidateFirst: planner([
        SystemIntentCandidateProvider(
          defaultDeterministicCatalog,
          intentGraph(),
          SystemIntentCatalog.builtin,
        ),
      ]),
      verifyGoal: (goal, {required planCompleted, expectation}) async =>
          const GoalVerification(GoalStatus.satisfied, 'verified'),
    );
    final r = await c.execute(const AutomationGoal(text: 'abre Bluetooth'));
    expect(r.status, AutomationResultStatus.completedUnverified);
    expect(dispatcher.calls.single.tool, 'open_system');
    expect(dispatcher.calls.single.args!['destination'], 'bluetooth_settings');
  });

  test('unknown → NoCandidate → legacy noPlan (sin LLM, sin crash)', () async {
    final dispatcher = _FakeDispatcher();
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      candidateFirst: planner([
        InstalledAppCandidateProvider(catalogWith(const [])),
      ]),
      // planner null: sin fallback LLM → noPlan.
    );
    final r = await c.execute(const AutomationGoal(text: 'abre nada'));
    expect(r.status, AutomationResultStatus.noPlan);
    expect(dispatcher.calls, isEmpty);
  });

  test('governance deny → denied, 0 dispatcher calls', () async {
    final dispatcher = _FakeDispatcher();
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      candidateFirst: planner([_FakeReplyProvider()]),
    );
    // "lee notificaciones" → intent read → reply_notification (send) → deny.
    final r = await c.execute(const AutomationGoal(text: 'lee notificaciones'));
    expect(r.status, AutomationResultStatus.denied);
    expect(dispatcher.calls, isEmpty);
  });

  test('legacy: catálogo determinista sigue funcionando (back)', () async {
    final dispatcher = _FakeDispatcher();
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      catalog: defaultDeterministicCatalog,
      // sin candidateFirst → legacy path.
    );
    final r = await c.execute(const AutomationGoal(text: 'volver'));
    expect(r.status, AutomationResultStatus.completedUnverified);
    expect(dispatcher.calls.single.tool, 'back');
  });

  test('ambigüedad → Koog selecciona candidateId → execution', () async {
    final dispatcher = _FakeDispatcher();
    final koog = KoogCandidateSelector(
      _FakeKoogClient('{"candidateId":"app:launch:com.whatsapp"}'),
    );
    final c = AutomationCoordinator(
      dispatcher: dispatcher,
      mode: () => AgentAutomationMode.autonomous,
      candidateFirst: planner([
        InstalledAppCandidateProvider(
          catalogWith([
            app('WhatsApp', 'com.whatsapp'),
            app('WhatsApp Business', 'com.whatsapp.w4b'),
          ]),
        ),
      ], koogSelector: koog),
      verifyGoal: (goal, {required planCompleted, expectation}) async =>
          const GoalVerification(GoalStatus.satisfied, 'verified'),
    );
    final r = await c.execute(const AutomationGoal(text: 'abre Whats'));
    expect(r.status, AutomationResultStatus.completed);
    expect(dispatcher.calls.single.tool, 'launch_app');
    expect(dispatcher.calls.single.args!['packageName'], 'com.whatsapp');
  });
}
