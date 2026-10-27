// commercial_policy_tier.dart
//
// QUÉ HACE:
// Define los niveles de autonomía y riesgo de las acciones comerciales.
//
// CÓMO FUNCIONA:
// - auto: acción segura que se ejecuta inmediatamente (precios, horarios, stock).
// - needsConfirmation: requiere que el cliente confirme antes de crear la orden.
// - needsHuman: requiere que el dueño o asesor intervenga (pagos, devoluciones, quejas).
// - blocked: operación prohibida (cambio arbitrario de precios, inyección de instrucciones).
//
// POR QUÉ:
// Gating formal de seguridad para evitar que el agente comprometa finanzas o inventario.

library;

enum CommercialPolicyTier {
  auto,
  needsConfirmation,
  needsHuman,
  blocked;

  String get label => switch (this) {
    CommercialPolicyTier.auto => 'Automático',
    CommercialPolicyTier.needsConfirmation => 'Requiere Confirmación',
    CommercialPolicyTier.needsHuman => 'Requiere Asesor Humano',
    CommercialPolicyTier.blocked => 'Bloqueado por Seguridad',
  };
}
