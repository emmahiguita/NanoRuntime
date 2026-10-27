part of 'semantic_policy.dart';

/// Contratos canónicos de acciones existentes; preserva sus entradas y efectos.
const _semanticPolicies2 = <String, SemanticActionDefinition>{
  'whatsapp.open_chat': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'whatsapp.send_message': SemanticActionDefinition(
    requiredInputs: ['contact', 'text'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresContextLock: true,
    requiresConfirmation: true,
  ),
  'whatsapp.share_file': SemanticActionDefinition(
    requiredInputs: ['contact', 'path'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresContextLock: true,
    requiresConfirmation: true,
  ),
  'telegram.contacts': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'telegram.open_chat': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'telegram.send_message': SemanticActionDefinition(
    requiredInputs: ['contact', 'text'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresContextLock: true,
    requiresConfirmation: true,
  ),
  'telegram.share_file': SemanticActionDefinition(
    requiredInputs: ['contact', 'path'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresContextLock: true,
    requiresConfirmation: true,
  ),
  'messenger.open_chat': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'messenger.send_message': SemanticActionDefinition(
    requiredInputs: ['contact', 'text'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresContextLock: true,
    requiresConfirmation: true,
  ),
  'messenger.share_file': SemanticActionDefinition(
    requiredInputs: ['contact', 'path'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
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
};
