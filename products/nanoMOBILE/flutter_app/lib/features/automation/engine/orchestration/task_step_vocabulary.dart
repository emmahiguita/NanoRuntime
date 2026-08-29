/// A15.2 — Vocabulario FINITO de pasos semánticos para la descomposición LLM.
///
/// El modelo puede emitir SOLO estos `semanticAction`. NUNCA tool names
/// arbitrarios, shell, packages, selectores, coordenadas, intents o privilegios.
/// Candidate-First decide CÓMO se ejecuta cada paso; el LLM solo dice QUÉ hacer.
library;

enum SemanticActionRisk {
  observation,
  navigation,
  reversibleWrite,
  irreversibleCommit,
}

enum SemanticReplayPolicy { never, safeReplace }

/// Contrato único de una acción que `TaskOrchestrator` puede ejecutar.
final class SemanticActionDefinition {
  final List<String> inputs;
  final SemanticActionRisk risk;
  final SemanticReplayPolicy replayPolicy;
  final bool rebuildOnResume;

  const SemanticActionDefinition({
    this.inputs = const [],
    required this.risk,
    this.replayPolicy = SemanticReplayPolicy.never,
    this.rebuildOnResume = false,
  });

  bool get irreversible => risk == SemanticActionRisk.irreversibleCommit;
}

/// Registro canónico de semánticas realmente ejecutables. El planner, el
/// journal y el retry loop consumen esta misma metadata.
const kSemanticActionRegistry = <String, SemanticActionDefinition>{
  'readNotification': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
    rebuildOnResume: true,
  ),
  'extractUrl': SemanticActionDefinition(
    inputs: ['text'],
    risk: SemanticActionRisk.observation,
    rebuildOnResume: true,
  ),
  'openApp': SemanticActionDefinition(
    inputs: ['package'],
    risk: SemanticActionRisk.navigation,
  ),
  'openUrl': SemanticActionDefinition(
    inputs: ['url'],
    risk: SemanticActionRisk.navigation,
  ),
  'openConversation': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'writeMessage': SemanticActionDefinition(
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
  'sendMessage': SemanticActionDefinition(
    risk: SemanticActionRisk.irreversibleCommit,
  ),
  'writeFile': SemanticActionDefinition(
    inputs: ['content'],
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
  'writeQuery': SemanticActionDefinition(
    inputs: ['query'],
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
  'submitSearch': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'selectResult': SemanticActionDefinition(
    inputs: ['ordinal', 'text'],
    risk: SemanticActionRisk.navigation,
  ),
};

final Set<String> kAllowedTaskSemantics = Set.unmodifiable(
  kSemanticActionRegistry.keys,
);

SemanticActionDefinition? semanticActionDefinition(String name) =>
    kSemanticActionRegistry[name];

/// Valida que una descomposición LLM solo use semántica permitida.
/// Devuelve el primer motivo de rechazo o null si es válida.
String? validateSemantics(List<String> semantics) {
  for (final s in semantics) {
    if (semanticActionDefinition(s) == null) {
      return 'semántica no permitida: $s';
    }
  }
  return null;
}

/// Parámetros que consume/produce cada semántica (para bindings tipados).
/// Evita que el LLM invente variables o tipos.
final Map<String, List<String>> kSemanticInputs = Map.unmodifiable({
  for (final entry in kSemanticActionRegistry.entries)
    entry.key: entry.value.inputs,
});
