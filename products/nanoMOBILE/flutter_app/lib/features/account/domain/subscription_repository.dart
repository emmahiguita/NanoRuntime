import 'billing_product.dart';
import 'subscription_plan.dart';

/// QUÉ HACE:
/// Puerto de facturación y gestión de suscripciones oficiales (SubscriptionPort).
///
/// CÓMO FUNCIONA:
/// Conecta la aplicación con el servicio de Google Play Billing y la validación
/// de entitlements del backend de Nano.
///
/// POR QUÉ:
/// Principio DIP: aísla la UI de Google Play Billing y evita que una modificación
/// maliciosa del cliente otorgue privilegios Pro sin verificación.
abstract class SubscriptionRepository {
  /// Emite actualizaciones en el plan del usuario.
  Stream<SubscriptionPlan> get subscriptionPlanStream;

  /// Obtiene la lista de productos y suscripciones disponibles desde Play Billing.
  Future<List<BillingProduct>> getAvailableProducts();

  /// Inicia el flujo oficial de compra en Google Play.
  Future<bool> purchaseSubscription(String productId);

  /// Restaura compras previas asociadas a la cuenta de Google Play del usuario.
  Future<SubscriptionPlan> restorePurchases();

  /// Obtiene el estado verificado de suscripción para el UID dado.
  Future<SubscriptionPlan> getCurrentSubscription(String uid);

  /// Abre la página de gestión de suscripciones de Google Play Store.
  Future<void> manageSubscription();
}
