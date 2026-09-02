/// Candidate providers (A6) — fuentes grounded de CandidateAction.
///
/// Cada provider convierte FACTS reales (catálogo determinista, catálogo de
/// apps, SystemGraph/SystemIntentCatalog, ExperienceCache) en CandidateAction[].
/// SIN ejecución, SIN política, SIN ranking, SIN LLM.
library;

import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/agent_tool_dispatcher.dart' show ToolCall;
import '../../execution/tool_registry.dart' show ToolRegistry, ToolRisk;
import '../../system/installed_app_catalog.dart'
    show
        AppMatchAmbiguous,
        AppMatchKind,
        AppMatchNotFound,
        AppMatchResolved,
        InstalledAppCatalog;
import '../../system/system_capability.dart' show SystemCapability;
import '../../system/system_destination.dart' show SystemDestination;
import '../../system/system_graph.dart' show SystemGraph;
import '../../system/system_intent_catalog.dart' show SystemIntentCatalog;
import '../../system/system_models.dart' show InstalledApp;
import '../deterministic_catalog.dart' show DeterministicFlowCatalog;
import '../../memory/experience_cache.dart' show ExperienceCache;
import 'candidate_action.dart';
import 'candidate_provider.dart';

String _semanticForTool(String tool) => switch (tool) {
  'back' => 'go_back',
  'notifications' => 'read_notifications',
  'launch_app' => 'open_app',
  'open_system' => 'open_system_destination',
  _ => tool,
};

String _semanticForDestination(SystemDestination d) => switch (d) {
  SystemDestination.settings => 'open_system_settings',
  SystemDestination.wifiSettings => 'open_wifi_settings',
  SystemDestination.bluetoothSettings => 'open_bluetooth_settings',
};

SystemCapability? _capabilityForDestination(SystemDestination d) => switch (d) {
  SystemDestination.settings => SystemCapability.openSystemSettings,
  SystemDestination.wifiSettings => SystemCapability.openWifiSettings,
  SystemDestination.bluetoothSettings => SystemCapability.openBluetoothSettings,
};

/// Deriva args canónicos (A4) desde un [ToolCall] (args si ya existen, o desde
/// los getters tipados para tools legacy). Nunca reintroduce selector/text/key
/// en el mundo Candidate-First.
Map<String, Object?> _canonicalArgs(ToolCall step) {
  if (step.args != null && step.args!.isNotEmpty) return step.args!;
  final out = <String, Object?>{};
  if (step.tool == 'launch_app' && step.packageNameArg != null) {
    out['packageName'] = step.packageNameArg;
  } else if (step.tool == 'open_system' && step.destinationArg != null) {
    out['destination'] = step.destinationArg;
  } else if (step.selectorArg != null) {
    out['selector'] = step.selectorArg;
  }
  if (step.textArg != null) out['text'] = step.textArg;
  if (step.keyArg != null) out['key'] = step.keyArg;
  return out;
}

/// Postcondición de acción derivada de un [ToolCall] (para flows de 1 paso).
/// Solo los casos con verificación factual clara (launch_app → foreground).
ActionExpectation? _expectationForStep(ToolCall step) {
  if (step.tool == 'launch_app' && step.packageNameArg != null) {
    return ActionExpectation(expectedPackage: step.packageNameArg);
  }
  return null;
}

/// Fuente: [DeterministicFlowCatalog]. Emite candidatos SOLO para acciones que
/// no tienen fuente más rica: `open_system` lo cubre SystemIntentProvider y
/// `launch_app` lo cubre InstalledAppProvider. Confianza 1.0 (flujo conocido).
class DeterministicCandidateProvider implements CandidateProvider {
  DeterministicCandidateProvider(this._catalog);

  final DeterministicFlowCatalog _catalog;

  @override
  String get id => 'deterministic';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final flow = _catalog.forGoal(request.goal);
    if (flow == null || flow.steps.length != 1) return const [];
    final step = flow.steps.single;
    if (step.tool == 'open_system' || step.tool == 'launch_app') {
      return const [];
    }
    return [
      CandidateAction(
        id: CandidateId('deterministic:${step.tool}'),
        semanticAction: _semanticForTool(step.tool),
        tool: step.tool,
        args: _canonicalArgs(step),
        channel: ActionChannel.deterministic,
        groundingConfidence: 1.0,
        risk: ToolRegistry.builtin.lookup(step.tool)?.risk ?? ToolRisk.device,
        reversible: true,
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.deterministicCatalog,
            reference: step.tool,
            confidence: 1.0,
          ),
        ],
      ),
    ];
  }
}

/// Fuente: [InstalledAppCatalog]. `packageName` SIEMPRE sale del catálogo,
/// nunca del string del modelo/usuario.
class InstalledAppCandidateProvider implements CandidateProvider {
  InstalledAppCandidateProvider(this._catalog);

  final InstalledAppCatalog _catalog;

  static const _openTerms = [
    'abrir',
    'abre',
    'lanza',
    'lanzar',
    'ejecuta',
    'ejecutar',
    'abrir la app',
    'abre la app',
    'abrir app',
    'abre app',
  ];

  @override
  String get id => 'installedApp';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final query = _appQuery(request.goal);
    if (query == null) return const [];
    final match = await _catalog.findApp(query);
    return switch (match) {
      AppMatchResolved(:final app) => [
        _candidate(app, _groundingFor(match.kind)),
      ],
      AppMatchAmbiguous(:final candidates) => [
        for (final a in candidates) _candidate(a, 0.5),
      ],
      AppMatchNotFound() => const [],
    };
  }

  CandidateAction _candidate(InstalledApp app, double grounding) =>
      CandidateAction(
        id: CandidateId('app:launch:${app.packageName}'),
        semanticAction: 'open_app',
        tool: 'launch_app',
        args: {'packageName': app.packageName},
        channel: ActionChannel.androidIntent,
        groundingConfidence: grounding,
        risk: ToolRisk.device,
        reversible: true,
        requiredCapabilities: const {SystemCapability.launchApps},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.packageManager,
            reference: app.packageName,
            confidence: grounding,
          ),
        ],
        expectation: ActionExpectation(expectedPackage: app.packageName),
      );

  double _groundingFor(AppMatchKind kind) => switch (kind) {
    AppMatchKind.exactLabel => 1.0,
    AppMatchKind.exactPackage => 1.0,
    AppMatchKind.qualifiedLabel => 0.9,
    AppMatchKind.prefixLabel => 0.8,
    AppMatchKind.token => 0.7,
  };

  String? _appQuery(String goal) {
    final g = goal.trim().toLowerCase();
    for (final t in _openTerms) {
      if (g.startsWith('$t ')) return g.substring(t.length).trim();
    }
    return null;
  }
}

/// Fuente: [SystemGraph] + [SystemIntentCatalog]. Solo destinos allowlisted y
/// solo si la capability está factualmente disponible. Nunca strings crudos de
/// Intent. Reusa el catálogo determinista para detectar el destination (sin
/// duplicar la lista de términos open/state-changing).
class SystemIntentCandidateProvider implements CandidateProvider {
  SystemIntentCandidateProvider(this._catalog, this._graph, this._intents);

  final DeterministicFlowCatalog _catalog;
  final SystemGraph _graph;
  final SystemIntentCatalog _intents;

  @override
  String get id => 'systemIntent';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final flow = _catalog.forGoal(request.goal);
    if (flow == null || flow.steps.length != 1) return const [];
    final step = flow.steps.single;
    if (step.tool != 'open_system') {
      return const [];
    }
    final wireId = step.destinationArg;
    if (wireId == null) return const [];
    final destination = SystemDestination.fromWireId(wireId);
    if (destination == null) return const [];
    if (_intents.metaFor(destination) == null) {
      return const []; // no allowlisted
    }
    final capability = _capabilityForDestination(destination);
    if (capability != null && !_graph.availabilityOf(capability).isAvailable) {
      return const []; // capability no disponible → no emitir candidato usable
    }
    return [
      CandidateAction(
        id: CandidateId('system:intent:${destination.wireId}'),
        semanticAction: _semanticForDestination(destination),
        tool: 'open_system',
        args: {'destination': destination.wireId},
        channel: ActionChannel.androidIntent,
        groundingConfidence: 1.0,
        risk: ToolRisk.device,
        reversible: true,
        requiredCapabilities: {if (capability != null) capability},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.systemIntentCatalog,
            reference: destination.wireId,
            confidence: 1.0,
          ),
          ActionEvidence(
            source: ActionEvidenceSource.systemGraph,
            reference: destination.wireId,
            confidence: 1.0,
          ),
        ],
      ),
    ];
  }
}

/// Fuente: [ExperienceCache] (flows VERIFICADOS, no completedUnverified).
/// Solo flows de 1 paso son una "acción" candidate. El channel `nanoFlow` lo
/// hace rankear por encima de fuentes equivalentes (aprendido > re-razonado).
class NanoFlowCandidateProvider implements CandidateProvider {
  NanoFlowCandidateProvider(this._cache);

  final ExperienceCache _cache;

  @override
  String get id => 'nanoFlow';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final flow = _cache.planFor(request.goal);
    if (flow == null || flow.steps.length != 1) return const [];
    final step = flow.steps.single;
    final key = request.goal.trim().toLowerCase();
    final confidence = flow.confidence.clamp(0.0, 1.0);
    return [
      CandidateAction(
        id: CandidateId('nanoflow:$key'),
        semanticAction: _semanticForTool(step.tool),
        tool: step.tool,
        args: _canonicalArgs(step),
        channel: ActionChannel.nanoFlow,
        groundingConfidence: confidence,
        risk: ToolRegistry.builtin.lookup(step.tool)?.risk ?? ToolRisk.device,
        reversible: true,
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.nanoFlow,
            reference: key,
            confidence: confidence,
          ),
        ],
        expectation: _expectationForStep(step),
      ),
    ];
  }
}
