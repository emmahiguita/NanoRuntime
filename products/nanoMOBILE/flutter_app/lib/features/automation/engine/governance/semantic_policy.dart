/// Política semántica canónica de Automation.
///
/// Planner determinista, planner LLM, TaskPlan y dispatcher consumen estas
/// mismas definiciones. El origen del plan nunca concede autoridad ni puede
/// rebajar riesgo, confirmación, evidencia o replay.
library;

part 'semantic_policies_0.dart';
part 'semantic_policies_1.dart';
part 'semantic_policies_2.dart';
part 'semantic_policies_3.dart';
part 'semantic_policies_4.dart';
part 'semantic_mcp_policies.dart';

enum SemanticActionRisk {
  observation,
  navigation,
  reversibleWrite,
  irreversibleCommit,
}

enum SemanticReplayPolicy { never, safeReplace }

/// Evidencia mínima que una acción exige de cada dependencia declarada.
enum RequiredEvidence { executed, verified }

/// Contrato inmutable de seguridad para una acción o herramienta.
final class SemanticActionDefinition {
  const SemanticActionDefinition({
    this.requiredInputs = const [],
    required this.risk,
    this.irreversible = false,
    this.replayPolicy = SemanticReplayPolicy.never,
    this.requiredEvidence = RequiredEvidence.executed,
    this.requiresContextLock = false,
    this.requiresConfirmation = false,
    this.rebuildOnResume = false,
  });

  final List<String> requiredInputs;
  final SemanticActionRisk risk;
  final bool irreversible;
  final SemanticReplayPolicy replayPolicy;
  final RequiredEvidence requiredEvidence;
  final bool requiresContextLock;
  final bool requiresConfirmation;
  final bool rebuildOnResume;

  /// Alias temporal para consumidores legacy del vocabulario de TaskPlan.
  List<String> get inputs => requiredInputs;
}

/// Fuente única de verdad. Incluye herramientas físicas y acciones de alto
/// nivel porque ambas terminan atravesando el mismo runtime gobernado.
const kAutomationSemanticPolicies = <String, SemanticActionDefinition>{
  ..._semanticPolicies0,
  ..._semanticPolicies1,
  ..._semanticPolicies2,
  ..._semanticPolicies3,
  ..._semanticPolicies4,
  ..._semanticMcpPolicies,
};

const kTaskSemanticActionNames = <String>{
  'readNotification',
  'extractUrl',
  'openApp',
  'openUrl',
  'openConversation',
  'activateElement',
  'fillElement',
  'writeMessage',
  'sendMessage',
  'writeFile',
  'writeQuery',
  'submitSearch',
  'selectResult',
  // GAP-06: pasos linux en planes multi-paso.
  'linux_list_files',
  'linux_read_file',
  'linux_write_file',
  'linux_run_command',
};

SemanticActionDefinition? automationSemanticPolicy(String name) =>
    kAutomationSemanticPolicies[name];

SemanticActionDefinition? taskSemanticPolicy(String name) =>
    kTaskSemanticActionNames.contains(name)
    ? kAutomationSemanticPolicies[name]
    : null;
