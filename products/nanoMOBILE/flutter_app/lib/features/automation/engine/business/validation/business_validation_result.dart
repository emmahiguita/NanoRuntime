// business_validation_result.dart
//
// QUÉ HACE:
// Define el resultado de la validación post-modelo contra la base de hechos (Truth Boundary).
//
// CÓMO FUNCIONA:
// - Estados sellados: Accepted (datos verificados y formateados), Rejected (datos inválidos),
//   Escalated (requiere intervención humana).
//
// POR QUÉ:
// Asegura que ninguna respuesta salga hacia el cliente si contiene discrepancias de datos.

library;

import '../business_product.dart';

sealed class BusinessValidationResult {
  const BusinessValidationResult();

  bool get isAccepted => this is AcceptedBusinessValidation;
  bool get isRejected => this is RejectedBusinessValidation;
  bool get isEscalated => this is EscalatedBusinessValidation;
}

final class AcceptedBusinessValidation extends BusinessValidationResult {
  final String formattedReply;
  final BusinessProduct? verifiedProduct;
  final List<String> suggestions;

  const AcceptedBusinessValidation({
    required this.formattedReply,
    this.verifiedProduct,
    this.suggestions = const [],
  });
}

final class RejectedBusinessValidation extends BusinessValidationResult {
  final String reason;
  final String fallbackReply;

  const RejectedBusinessValidation({
    required this.reason,
    required this.fallbackReply,
  });
}

final class EscalatedBusinessValidation extends BusinessValidationResult {
  final String reason;
  final String noticeToCustomer;

  const EscalatedBusinessValidation({
    required this.reason,
    required this.noticeToCustomer,
  });
}
