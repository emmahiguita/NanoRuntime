/// Política semántica canónica de Automation.
///
/// Planner determinista, planner LLM, TaskPlan y dispatcher consumen estas
/// mismas definiciones. El origen del plan nunca concede autoridad ni puede
/// rebajar riesgo, confirmación, evidencia o replay.
library;

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
  // Herramientas de observación.
  'screen': SemanticActionDefinition(risk: SemanticActionRisk.observation),
  'resolve': SemanticActionDefinition(
    requiredInputs: ['selector'],
    risk: SemanticActionRisk.observation,
  ),
  'notifications': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'linux.list': SemanticActionDefinition(
    requiredInputs: ['path'],
    risk: SemanticActionRisk.observation,
  ),
  'linux.readFile': SemanticActionDefinition(
    requiredInputs: ['path'],
    risk: SemanticActionRisk.observation,
  ),
  'shizuku_query_package': SemanticActionDefinition(
    requiredInputs: ['packageName'],
    risk: SemanticActionRisk.observation,
  ),

  // Navegación y control del dispositivo.
  'tap': SemanticActionDefinition(
    requiredInputs: ['selector'],
    risk: SemanticActionRisk.navigation,
    irreversible: true,
  ),
  'back': SemanticActionDefinition(risk: SemanticActionRisk.navigation),
  'launch_app': SemanticActionDefinition(
    requiredInputs: ['packageName'],
    risk: SemanticActionRisk.navigation,
  ),
  'home': SemanticActionDefinition(risk: SemanticActionRisk.navigation),
  'recents': SemanticActionDefinition(risk: SemanticActionRisk.navigation),
  'open_notifications': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'open_quick_settings': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'swipe': SemanticActionDefinition(
    requiredInputs: ['x1', 'y1', 'x2', 'y2'],
    risk: SemanticActionRisk.navigation,
  ),
  'scroll': SemanticActionDefinition(
    requiredInputs: ['direction'],
    risk: SemanticActionRisk.navigation,
  ),
  'long_press': SemanticActionDefinition(
    requiredInputs: ['x', 'y'],
    risk: SemanticActionRisk.navigation,
  ),
  'open_system': SemanticActionDefinition(
    requiredInputs: ['destination'],
    risk: SemanticActionRisk.navigation,
  ),
  'open_url': SemanticActionDefinition(
    requiredInputs: ['url'],
    risk: SemanticActionRisk.navigation,
  ),

  // Escrituras y operaciones privilegiadas.
  'write': SemanticActionDefinition(
    requiredInputs: ['selector', 'text'],
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
    requiresConfirmation: true,
  ),
  'reply_notification': SemanticActionDefinition(
    requiredInputs: ['key', 'text'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiredEvidence: RequiredEvidence.verified,
    requiresContextLock: true,
    requiresConfirmation: true,
  ),
  'linux.writeFile': SemanticActionDefinition(
    requiredInputs: ['path', 'content'],
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
    requiresConfirmation: true,
  ),
  'linux.run': SemanticActionDefinition(
    requiredInputs: ['command'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresConfirmation: true,
  ),
  'force_stop_package': SemanticActionDefinition(
    requiredInputs: ['packageName'],
    risk: SemanticActionRisk.reversibleWrite,
    requiresConfirmation: true,
  ),
  'install_package': SemanticActionDefinition(
    requiredInputs: ['apkPath'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiredEvidence: RequiredEvidence.verified,
    requiresConfirmation: true,
  ),
  'grant_specific_permission': SemanticActionDefinition(
    requiredInputs: ['packageName', 'permission'],
    risk: SemanticActionRisk.reversibleWrite,
    requiresConfirmation: true,
  ),

  // Vocabulario de alto nivel de TaskPlan.
  'readNotification': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
    rebuildOnResume: true,
  ),
  'extractUrl': SemanticActionDefinition(
    requiredInputs: ['text'],
    risk: SemanticActionRisk.observation,
    rebuildOnResume: true,
  ),
  'openApp': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
    rebuildOnResume: true,
  ),
  'openUrl': SemanticActionDefinition(
    requiredInputs: ['url'],
    risk: SemanticActionRisk.navigation,
  ),
  'openConversation': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
    replayPolicy: SemanticReplayPolicy.safeReplace,
    rebuildOnResume: true,
  ),
  'writeMessage': SemanticActionDefinition(
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
  'sendMessage': SemanticActionDefinition(
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiredEvidence: RequiredEvidence.verified,
    requiresContextLock: true,
    requiresConfirmation: true,
  ),
  'writeFile': SemanticActionDefinition(
    requiredInputs: ['content'],
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
  'writeQuery': SemanticActionDefinition(
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
  'submitSearch': SemanticActionDefinition(risk: SemanticActionRisk.navigation),
  'selectResult': SemanticActionDefinition(risk: SemanticActionRisk.navigation),
};

const kTaskSemanticActionNames = <String>{
  'readNotification',
  'extractUrl',
  'openApp',
  'openUrl',
  'openConversation',
  'writeMessage',
  'sendMessage',
  'writeFile',
  'writeQuery',
  'submitSearch',
  'selectResult',
};

SemanticActionDefinition? automationSemanticPolicy(String name) =>
    kAutomationSemanticPolicies[name];

SemanticActionDefinition? taskSemanticPolicy(String name) =>
    kTaskSemanticActionNames.contains(name)
    ? kAutomationSemanticPolicies[name]
    : null;
