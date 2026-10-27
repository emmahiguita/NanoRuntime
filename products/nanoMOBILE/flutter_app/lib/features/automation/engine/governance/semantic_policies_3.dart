part of 'semantic_policy.dart';

/// Contratos canónicos de acciones existentes; preserva sus entradas y efectos.
const _semanticPolicies3 = <String, SemanticActionDefinition>{
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
  // Revela una única superficie transitoria (p. ej. overflow) para que el
  // target pedido pueda observarse. No activa el target final ni hereda su
  // autoridad; ese segundo tap conserva la política de activateElement.
  'revealElement': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
  // Un toque genérico puede confirmar, comprar, eliminar o enviar según la
  // app. Se clasifica conservadoramente como commit hasta conocer su dominio.
  // La re-resolución del selector y la verificación del snapshot siguen en el
  // executor; la confirmación nunca se hereda del origen del plan.
  'activateElement': SemanticActionDefinition(
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiredEvidence: RequiredEvidence.verified,
    requiresConfirmation: true,
  ),
  'fillElement': SemanticActionDefinition(
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
    requiredEvidence: RequiredEvidence.verified,
    requiresConfirmation: true,
  ),
  'writeMessage': SemanticActionDefinition(
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
  ),
};
