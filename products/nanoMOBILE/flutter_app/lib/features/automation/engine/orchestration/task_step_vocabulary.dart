/// A15.2 — Vocabulario FINITO de pasos semánticos para la descomposición LLM.
///
/// El modelo puede emitir SOLO estos `semanticAction`. NUNCA tool names
/// arbitrarios, shell, packages, selectores, coordenadas, intents o privilegios.
/// Candidate-First decide CÓMO se ejecuta cada paso; el LLM solo dice QUÉ hacer.
library;

import '../governance/semantic_policy.dart';

export '../governance/semantic_policy.dart'
    show
        RequiredEvidence,
        SemanticActionDefinition,
        SemanticActionRisk,
        SemanticReplayPolicy;

/// Vista acotada para TaskPlan sobre la política canónica de Automation.
final Map<String, SemanticActionDefinition> kSemanticActionRegistry =
    Map.unmodifiable({
      for (final name in kTaskSemanticActionNames)
        name: kAutomationSemanticPolicies[name]!,
    });

final Set<String> kAllowedTaskSemantics = Set.unmodifiable(
  kSemanticActionRegistry.keys,
);

SemanticActionDefinition? semanticActionDefinition(String name) =>
    taskSemanticPolicy(name);

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
    entry.key: entry.value.requiredInputs,
});
