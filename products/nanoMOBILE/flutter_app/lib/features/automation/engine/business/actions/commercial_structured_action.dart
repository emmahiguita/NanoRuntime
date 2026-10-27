// commercial_structured_action.dart
//
// QUÉ HACE:
// Define el contrato tipado de acciones comerciales que el SLM o el motor determinista
// pueden generar. Elimina la generación de texto libre no verificado para datos de negocio.
//
// CÓMO FUNCIONA:
// - Jerarquía sellada (sealed class) con acciones específicas (PriceQuery, StockQuery, etc.).
// - Serialización bidireccional JSON para que el modelo local emita estructuras limpias.
//
// POR QUÉ:
// Base del principio Zero-Alucinación: el modelo solo propone una intención y referencias;
// los datos reales (precios, stock) se extraen exclusivamente de BusinessFacts.

library;

/// Jerarquía sellada de acciones comerciales tipadas.
sealed class CommercialStructuredAction {
  const CommercialStructuredAction();

  Map<String, dynamic> toJson();
}

/// Consulta de precio para un producto o variante específica.
final class PriceQueryAction extends CommercialStructuredAction {
  final String productId;
  final String? variantId;

  const PriceQueryAction({
    required this.productId,
    this.variantId,
  });

  @override
  Map<String, dynamic> toJson() => {
    'action': 'price_query',
    'productId': productId,
    if (variantId != null) 'variantId': variantId,
  };

  factory PriceQueryAction.fromJson(Map<String, dynamic> json) =>
      PriceQueryAction(
        productId: (json['productId'] as String?) ?? '',
        variantId: json['variantId'] as String?,
      );
}

/// Consulta de disponibilidad o stock de un producto.
final class StockQueryAction extends CommercialStructuredAction {
  final String productId;

  const StockQueryAction({required this.productId});

  @override
  Map<String, dynamic> toJson() => {
    'action': 'stock_query',
    'productId': productId,
  };

  factory StockQueryAction.fromJson(Map<String, dynamic> json) =>
      StockQueryAction(
        productId: (json['productId'] as String?) ?? '',
      );
}

/// Consulta general de catálogo o categoría.
final class CatalogQueryAction extends CommercialStructuredAction {
  final String? category;

  const CatalogQueryAction({this.category});

  @override
  Map<String, dynamic> toJson() => {
    'action': 'catalog_query',
    if (category != null) 'category': category,
  };

  factory CatalogQueryAction.fromJson(Map<String, dynamic> json) =>
      CatalogQueryAction(
        category: json['category'] as String?,
      );
}

/// Solicitud de añadir un producto al carrito de compra.
final class AddToCartAction extends CommercialStructuredAction {
  final String productId;
  final int quantity;
  final String? variantId;

  const AddToCartAction({
    required this.productId,
    this.quantity = 1,
    this.variantId,
  });

  @override
  Map<String, dynamic> toJson() => {
    'action': 'add_to_cart',
    'productId': productId,
    'quantity': quantity,
    if (variantId != null) 'variantId': variantId,
  };

  factory AddToCartAction.fromJson(Map<String, dynamic> json) =>
      AddToCartAction(
        productId: (json['productId'] as String?) ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        variantId: json['variantId'] as String?,
      );
}

/// Notificación o reclamo de pago por parte del cliente.
final class PaymentClaimAction extends CommercialStructuredAction {
  final String? referenceCode;
  final double? claimedAmount;
  final String? paymentMethod;

  const PaymentClaimAction({
    this.referenceCode,
    this.claimedAmount,
    this.paymentMethod,
  });

  @override
  Map<String, dynamic> toJson() => {
    'action': 'payment_claim',
    if (referenceCode != null) 'referenceCode': referenceCode,
    if (claimedAmount != null) 'claimedAmount': claimedAmount,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
  };

  factory PaymentClaimAction.fromJson(Map<String, dynamic> json) =>
      PaymentClaimAction(
        referenceCode: json['referenceCode'] as String?,
        claimedAmount: (json['claimedAmount'] as num?)?.toDouble(),
        paymentMethod: json['paymentMethod'] as String?,
      );
}

/// Consulta de políticas del negocio (horarios, ubicación, envíos, métodos de pago).
final class PolicyQueryAction extends CommercialStructuredAction {
  final String policyTopic; // 'hours', 'delivery', 'payments', 'location'

  const PolicyQueryAction({required this.policyTopic});

  @override
  Map<String, dynamic> toJson() => {
    'action': 'policy_query',
    'policyTopic': policyTopic,
  };

  factory PolicyQueryAction.fromJson(Map<String, dynamic> json) =>
      PolicyQueryAction(
        policyTopic: (json['policyTopic'] as String?) ?? 'general',
      );
}

/// Escalamiento explícito a un asesor humano.
final class EscalateToHumanAction extends CommercialStructuredAction {
  final String reason;
  final String? customerInquiry;

  const EscalateToHumanAction({
    required this.reason,
    this.customerInquiry,
  });

  @override
  Map<String, dynamic> toJson() => {
    'action': 'escalate_to_human',
    'reason': reason,
    if (customerInquiry != null) 'customerInquiry': customerInquiry,
  };

  factory EscalateToHumanAction.fromJson(Map<String, dynamic> json) =>
      EscalateToHumanAction(
        reason: (json['reason'] as String?) ?? 'No especificada',
        customerInquiry: json['customerInquiry'] as String?,
      );
}
