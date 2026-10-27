// commercial_action_policy_engine.dart
//
// QUÉ HACE:
// Motor de políticas y control de acceso para acciones comerciales (ActionPolicyEngine).
//
// CÓMO FUNCIONA:
// - Clasifica cada acción entrante en una de las 4 categorías de riesgo (auto, needsConfirmation,
//   needsHuman, blocked).
// - Evalúa si la acción está permitida bajo el perfil actual del negocio.
//
// POR QUÉ:
// Asegura que las operaciones críticas (confirmación de pagos, descuentos, cancelaciones)
// jamás se ejecuten sin supervisión humana.

library;

import '../actions/commercial_structured_action.dart';
import '../business_facts.dart';
import 'commercial_policy_tier.dart';

final class PolicyEvaluationResult {
  final CommercialPolicyTier tier;
  final String reason;
  final bool allowed;

  const PolicyEvaluationResult({
    required this.tier,
    required this.reason,
    required this.allowed,
  });
}

class CommercialActionPolicyEngine {
  final BusinessFacts facts;

  const CommercialActionPolicyEngine(this.facts);

  PolicyEvaluationResult evaluate(CommercialStructuredAction action) {
    return switch (action) {
      PriceQueryAction _ => const PolicyEvaluationResult(
          tier: CommercialPolicyTier.auto,
          reason: 'Consulta de precio autorizada sobre catálogo registrado',
          allowed: true,
        ),
      StockQueryAction _ => const PolicyEvaluationResult(
          tier: CommercialPolicyTier.auto,
          reason: 'Consulta de inventario permitida',
          allowed: true,
        ),
      CatalogQueryAction _ => const PolicyEvaluationResult(
          tier: CommercialPolicyTier.auto,
          reason: 'Consulta general de catálogo autorizada',
          allowed: true,
        ),
      PolicyQueryAction _ => const PolicyEvaluationResult(
          tier: CommercialPolicyTier.auto,
          reason: 'Consulta de horarios/políticas permitida',
          allowed: true,
        ),
      AddToCartAction _ => const PolicyEvaluationResult(
          tier: CommercialPolicyTier.needsConfirmation,
          reason: 'Añadir al carrito requiere validación de stock y confirmación del cliente',
          allowed: true,
        ),
      PaymentClaimAction _ => const PolicyEvaluationResult(
          tier: CommercialPolicyTier.needsHuman,
          reason: 'Comprobantes de pago requieren verificación bancaria o intervención humana',
          allowed: false,
        ),
      EscalateToHumanAction a => PolicyEvaluationResult(
          tier: CommercialPolicyTier.needsHuman,
          reason: a.reason,
          allowed: false,
        ),
    };
  }

  /// Valida si un texto entrante contiene patrones de inyección de prompt comercial
  bool detectPromptInjection(String rawInput) {
    final lower = rawInput.toLowerCase();
    return lower.contains('ignora las instrucciones') ||
        lower.contains('ignora tus instrucciones') ||
        lower.contains('olvida las reglas') ||
        lower.contains('vendeme todo a') ||
        lower.contains('descuento del 100') ||
        lower.contains('precio: 0') ||
        lower.contains('precio 0') ||
        lower.contains('cambia el precio') ||
        lower.contains('eres el dueño y me autorizas');
  }
}
