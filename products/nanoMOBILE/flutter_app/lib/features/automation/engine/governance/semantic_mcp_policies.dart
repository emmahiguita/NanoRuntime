part of 'semantic_policy.dart';

/// Contratos MCP y servicios auxiliares: el transporte no define consentimiento.
const _semanticMcpPolicies = <String, SemanticActionDefinition>{
  'mcp.read': SemanticActionDefinition(
    requiredInputs: ['mcpTool'],
    risk: SemanticActionRisk.observation,
  ),
  'mcp.device': SemanticActionDefinition(
    requiredInputs: ['mcpTool'],
    risk: SemanticActionRisk.navigation,
    requiresConfirmation: true,
  ),
  'mcp.externalWrite': SemanticActionDefinition(
    requiredInputs: ['mcpTool'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresConfirmation: true,
  ),
  'mcp.privileged': SemanticActionDefinition(
    requiredInputs: ['mcpTool'],
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresConfirmation: true,
  ),
  // Los servicios de lectura siguen disponibles sin dar shell libre al modelo.
  'dev.inspect_app': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'dev.diagnostics': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'dev.run_benchmark': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
    requiresConfirmation: true,
  ),
  'dev.adb': SemanticActionDefinition(
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresConfirmation: true,
  ),
  'search_knowledge': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'browser_ai_query': SemanticActionDefinition(
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresConfirmation: true,
  ),
  'browser.ai.ask': SemanticActionDefinition(
    risk: SemanticActionRisk.irreversibleCommit,
    irreversible: true,
    requiresConfirmation: true,
  ),
  'browser.ai.providers': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'browser.ai.get_response': SemanticActionDefinition(
    risk: SemanticActionRisk.observation,
  ),
  'browser.ai.open': SemanticActionDefinition(
    risk: SemanticActionRisk.navigation,
  ),
  'device.set_alarm': SemanticActionDefinition(
    risk: SemanticActionRisk.reversibleWrite,
    requiresConfirmation: true,
  ),
};
