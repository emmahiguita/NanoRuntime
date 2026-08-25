/// McpToolAdapter (A14) — convierte una MCP tool tipada en un CandidateAction
/// grounded, que pasa por el governance A11 ANTES de ejecutarse. Nunca produce
/// shell arbitrario ni bypass.
library;

import '../planning/candidates/candidate_action.dart';
import '../execution/tool_registry.dart' show ToolRisk;
import '../system/system_capability.dart';
import 'mcp_tool.dart';

class McpToolAdapter {
  const McpToolAdapter();

  CandidateAction adapt(McpTool tool, Map<String, Object?> args) {
    return CandidateAction(
      id: CandidateId('mcp:${tool.id}'),
      semanticAction: tool.name,
      // Tool categórico: el effectOfTool (A11) lo mapea a un efecto. El executor
      // MCP real (futuro) resuelve el id concreto desde args.
      tool: 'mcp.${tool.category.name}',
      args: {'mcpTool': tool.id, ...args},
      channel: ActionChannel.mcp,
      groundingConfidence: 1.0, // tool declarada/estructurada (no inventada)
      risk: _riskFor(tool.category),
      reversible: tool.category == McpToolCategory.read,
      requiredCapabilities: _capabilitiesFor(tool.category),
      evidence: [
        ActionEvidence(
          source: ActionEvidenceSource.explicitConfiguration,
          reference: tool.id,
          confidence: 1.0,
        ),
      ],
    );
  }

  ToolRisk _riskFor(McpToolCategory category) => switch (category) {
    McpToolCategory.read => ToolRisk.read,
    McpToolCategory.device => ToolRisk.device,
    McpToolCategory.externalWrite ||
    McpToolCategory.privileged => ToolRisk.externalWrite,
  };

  Set<SystemCapability> _capabilitiesFor(
    McpToolCategory category,
  ) => switch (category) {
    // El backend privilegiado concreto (shizuku/deviceOwner/root) es futuro;
    // A14 usa shizuku como ejemplo mínimo. El broker lo marca unavailable.
    McpToolCategory.privileged => const {SystemCapability.shizuku},
    _ => const {},
  };
}
