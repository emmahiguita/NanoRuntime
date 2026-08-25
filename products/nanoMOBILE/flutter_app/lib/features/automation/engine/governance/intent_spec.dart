/// IntentSpec (A11) — frontera semántica tipada de lo que el usuario autorizó.
///
/// CAPABILITY != AUTHORITY: el IntentSpec es la AUTORIDAD (efectos permitidos),
/// distinta de la CAPACIDAD técnica (SystemGraph), el PRIVILEGIO de backend
/// (PrivilegeBroker) y la POLÍTICA de producto (PolicyEngine).
///
/// El IntentSpec NO es el texto crudo del goal; es el límite semántico tipado.
/// El contenido observado (Accessibility/OCR/Vision/notificación/web) NUNCA
/// amplía el IntentSpec (solo puede aportar TARGET DATA).
library;

/// Efectos acotados (no un enum de miles de acciones específicas de app).
enum ActionEffect {
  navigate,
  read,
  writeUi,
  changeSystemState,
  sendExternalMessage,
  publishExternalContent,
  modifyFile,
  deleteFile,
  executeProcess,
  installPackage,
  manageApplication,
  changePermission,
  privilegedSystemOperation,
}

/// Códigos de razón tipados (no solo strings) para decisiones de gobierno.
enum GovernanceReason {
  outsideIntent,
  targetMismatch,
  ambiguousTarget,
  insufficientEvidence,
  capabilityUnavailable,
  requiresEnablement,
  highRisk,
  irreversible,
  privilegeUnavailable,
  policyConfirmation,
}

/// Efecto autorizado por el usuario, con scope de target opcional.
/// `targetScope` (String normalizado) delimita el target: ej. `juan` (contacto),
/// `com.whatsapp` (app), `/workspace/foo` (path). No otorga wildcard.
class IntentSpec {
  final String id;
  final Set<ActionEffect> allowedEffects;

  /// Scope de target (null = sin restricción de target para el efecto).
  final String? targetScope;

  const IntentSpec({
    required this.id,
    required this.allowedEffects,
    this.targetScope,
  });

  bool allows(ActionEffect effect) => allowedEffects.contains(effect);
}
