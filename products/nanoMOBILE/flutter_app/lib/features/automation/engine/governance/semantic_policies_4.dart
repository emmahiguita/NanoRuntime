part of 'semantic_policy.dart';

/// Contratos canónicos de acciones existentes; preserva sus entradas y efectos.
const _semanticPolicies4 = <String, SemanticActionDefinition>{
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
  // GAP-06: vocabulario linux para planes multi-paso del TaskOrchestrator.
  // El dispatcher los traduce a linux.list/readFile/writeFile/run.
  'linux_list_files': SemanticActionDefinition(
    requiredInputs: ['path'],
    risk: SemanticActionRisk.observation,
  ),
  'linux_read_file': SemanticActionDefinition(
    requiredInputs: ['path'],
    risk: SemanticActionRisk.observation,
  ),
  'linux_write_file': SemanticActionDefinition(
    requiredInputs: ['path', 'content'],
    risk: SemanticActionRisk.reversibleWrite,
    replayPolicy: SemanticReplayPolicy.safeReplace,
    requiresConfirmation: true,
  ),
  'linux_run_command': SemanticActionDefinition(
    requiredInputs: ['command'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresConfirmation: true,
  ),
};
