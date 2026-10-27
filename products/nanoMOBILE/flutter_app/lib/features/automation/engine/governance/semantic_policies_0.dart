part of 'semantic_policy.dart';

/// Contratos canónicos de acciones existentes; preserva sus entradas y efectos.
const _semanticPolicies0 = <String, SemanticActionDefinition>{
  'screen': SemanticActionDefinition(risk: SemanticActionRisk.observation),
  'read_screen': SemanticActionDefinition(risk: SemanticActionRisk.observation),
  'resolve': SemanticActionDefinition(
    requiredInputs: ['selector'],
    risk: SemanticActionRisk.observation,
  ),
  'notifications': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'device_state': SemanticActionDefinition(
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
};
