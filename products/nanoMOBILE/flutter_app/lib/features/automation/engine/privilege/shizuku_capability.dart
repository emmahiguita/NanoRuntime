/// Shizuku (A14) — backend privilegiado OPCIONAL con herramientas TIPADAS.
///
/// Nunca se expone `executeShell(String arbitraryCommand)` al modelo. Solo
/// capacidades tipadas (install/force-stop/grant/query) con schema + risk +
/// policy + verification. El governance A11 (PrivilegeBroker) las marca
/// unavailable hasta que el backend exista. Shizuku NO es requisito.
library;

import '../execution/tool_registry.dart' show ToolRisk;
import '../planning/candidates/candidate_action.dart';
import '../system/system_capability.dart';

enum ShizukuCapability {
  installPackage,
  forceStopPackage,
  grantSpecificPermission,
  queryPackage,
}

/// Genera CandidateAction tipados para capacidades Shizuku. Cada acción lleva
/// capability `shizuku` → el PrivilegeBroker la resuelve a tier `shizuku`
/// (unavailable en A14). NO hay shell arbitrario.
class ShizukuCapabilityProvider {
  const ShizukuCapabilityProvider();

  CandidateAction capability(ShizukuCapability cap, Map<String, Object?> args) {
    return CandidateAction(
      id: CandidateId('shizuku:${cap.name}'),
      semanticAction: cap.name,
      tool: _toolName(cap),
      args: args,
      channel: ActionChannel.shizuku,
      groundingConfidence: 1.0, // capacidad tipada, no inventada
      risk: ToolRisk.externalWrite,
      reversible: cap == ShizukuCapability.queryPackage,
      requiredCapabilities: const {SystemCapability.shizuku},
      evidence: [
        ActionEvidence(
          source: ActionEvidenceSource.explicitConfiguration,
          reference: cap.name,
          confidence: 1.0,
        ),
      ],
    );
  }

  /// Tool name en snake_case (coincide con el effectOfTool del firewall A11).
  String _toolName(ShizukuCapability cap) => switch (cap) {
    ShizukuCapability.installPackage => 'install_package',
    ShizukuCapability.forceStopPackage => 'force_stop_package',
    ShizukuCapability.grantSpecificPermission => 'grant_specific_permission',
    ShizukuCapability.queryPackage => 'query_package',
  };
}
