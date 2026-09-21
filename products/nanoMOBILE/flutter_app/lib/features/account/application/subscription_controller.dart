import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/account_exceptions.dart';
import '../domain/billing_product.dart';
import '../domain/subscription_plan.dart';
import '../domain/subscription_repository.dart';

/// QUÉ HACE:
/// Gestiona el estado de planes, compras y restauración de suscripciones.
///
/// CÓMO FUNCIONA:
/// Obtiene el catálogo de Google Play, coordina las compras mediante Play Billing
/// y actualiza los entitlements verificados de la cuenta.
///
/// POR QUÉ:
/// Asegura que la UI consuma precios reales y nunca altere arbitrariamente el plan.
class SubscriptionState {
  final SubscriptionPlan plan;
  final List<BillingProduct> products;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const SubscriptionState({
    required this.plan,
    this.products = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  SubscriptionState copyWith({
    SubscriptionPlan? plan,
    List<BillingProduct>? products,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return SubscriptionState(
      plan: plan ?? this.plan,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repository;
  StreamSubscription<SubscriptionPlan>? _subscription;

  SubscriptionController(this._repository)
    : super(const SubscriptionState(plan: SubscriptionPlan.freeDefault)) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final products = await _repository.getAvailableProducts();
    state = state.copyWith(products: products, isLoading: false);

    _subscription = _repository.subscriptionPlanStream.listen((plan) {
      state = state.copyWith(plan: plan);
    });
  }

  Future<bool> purchase(String productId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final success = await _repository.purchaseSubscription(productId);
      state = state.copyWith(
        isLoading: false,
        successMessage: '¡Suscripción activada con éxito!',
      );
      return success;
    } on AccountException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al procesar la compra en Google Play.',
      );
      return false;
    }
  }

  Future<void> restore() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final restored = await _repository.restorePurchases();
      if (restored.isProOrHigher) {
        state = state.copyWith(
          plan: restored,
          isLoading: false,
          successMessage: '✓ Compras restauradas exitosamente.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No encontramos una suscripción activa para esta cuenta.',
        );
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al consultar compras anteriores.',
      );
    }
  }

  Future<void> manage() async {
    await _repository.manageSubscription();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
