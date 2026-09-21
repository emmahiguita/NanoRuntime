import 'subscription_plan.dart';

/// QUÉ HACE:
/// Representa un producto o suscripción ofrecido en Google Play Store.
///
/// CÓMO FUNCIONA:
/// Almacena los metadatos y precio localizado provisto directamente por Play Billing.
/// Ningún precio se encuentra hardcodeado en la interfaz.
///
/// POR QUÉ:
/// Cumple la política de Google Play: los precios y monedas deben reflejar exactamente
/// los valores del país y la tienda del usuario (ProductDetails).
class BillingProduct {
  final String productId;
  final String title;
  final String description;
  final String formattedPrice;
  final String currencyCode;
  final SubscriptionTier tier;
  final String billingPeriod; // mes, año

  const BillingProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.formattedPrice,
    required this.currencyCode,
    required this.tier,
    this.billingPeriod = 'mes',
  });

  BillingProduct copyWith({
    String? productId,
    String? title,
    String? description,
    String? formattedPrice,
    String? currencyCode,
    SubscriptionTier? tier,
    String? billingPeriod,
  }) {
    return BillingProduct(
      productId: productId ?? this.productId,
      title: title ?? this.title,
      description: description ?? this.description,
      formattedPrice: formattedPrice ?? this.formattedPrice,
      currencyCode: currencyCode ?? this.currencyCode,
      tier: tier ?? this.tier,
      billingPeriod: billingPeriod ?? this.billingPeriod,
    );
  }
}
