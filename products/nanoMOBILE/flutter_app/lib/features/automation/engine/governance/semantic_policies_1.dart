part of 'semantic_policy.dart';

/// Contratos canónicos de acciones existentes; preserva sus entradas y efectos.
const _semanticPolicies1 = <String, SemanticActionDefinition>{
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
  'fetch_web': SemanticActionDefinition(
    requiredInputs: ['url'],
    risk: SemanticActionRisk.observation,
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
  'whatsapp.contacts': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
};
