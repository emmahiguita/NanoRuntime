/// CapabilityAvailability (A3) — estado tipado de una capability.
///
/// Preferir estado explícito sobre bool: `requiresAccessibility` le dice al
/// orquestador POR QUÉ no puede ejecutar, no solo "no puede". El motivo
/// legible vive en [reason]; las decisiones de negocio NO se codifican en el
/// string (el estado es el tipo).
library;

import 'system_capability.dart';

enum CapabilityAvailabilityKind {
  available,
  unavailable,
  requiresUserEnablement,
  requiresAccessibility,
  requiresNotificationAccess,
  unsupported,
  unknown,
}

class CapabilityAvailability {
  final SystemCapability capability;
  final CapabilityAvailabilityKind state;
  final String reason;
  final List<SystemEvidence> evidence;

  const CapabilityAvailability({
    required this.capability,
    required this.state,
    required this.reason,
    this.evidence = const [],
  });

  /// Estado por defecto de una capability no observada: explícito, no bool.
  factory CapabilityAvailability.unknown(SystemCapability capability) =>
      CapabilityAvailability(
        capability: capability,
        state: CapabilityAvailabilityKind.unknown,
        reason: 'No observado.',
      );

  bool get isAvailable => state == CapabilityAvailabilityKind.available;
}
