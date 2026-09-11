/// WA-BUSINESS-01 — providers de hechos del negocio. La carga entra en la
/// barrera global de hidratación (automationStoresHydratedProvider) y el
/// bloque se lee EN VIVO en cada borrador (editar catálogo aplica desde el
/// siguiente mensaje, sin reconstruir el writer).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_facts.dart';

final businessFactsStoreProvider = Provider<BusinessFactsStore>((ref) {
  return const BusinessFactsStore();
});

final class BusinessFactsNotifier extends StateNotifier<BusinessFacts> {
  BusinessFactsNotifier(this._store) : super(const BusinessFacts());

  final BusinessFactsStore _store;
  Future<void>? _loading;

  /// Futuro compartido de la carga (idempotente — patrón del módulo).
  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      state = await _store.load();
    } on Object {
      // Sin datos: estado vacío honesto.
    }
  }

  Future<void> reload() async {
    _loading = null;
    await ready;
  }

  Future<bool> loadPreset(BusinessFacts preset) => _persist(preset);

  Future<bool> upsertProduct(BusinessProduct product) {
    final next = BusinessFacts(
      products: [
        for (final p in state.products)
          if (p.id != product.id) p,
        product,
      ],
      hours: state.hours,
      delivery: state.delivery,
      payments: state.payments,
      location: state.location,
    );
    return _persist(next);
  }

  Future<bool> removeProduct(String id) {
    return _persist(
      BusinessFacts(
        products: [
          for (final p in state.products)
            if (p.id != id) p,
        ],
        hours: state.hours,
        delivery: state.delivery,
        payments: state.payments,
        location: state.location,
      ),
    );
  }

  Future<bool> setHours(String hours) {
    return _persist(
      BusinessFacts(
        products: state.products,
        hours: hours.trim(),
        delivery: state.delivery,
        payments: state.payments,
        location: state.location,
      ),
    );
  }

  Future<bool> setDelivery(String delivery) {
    return _persist(
      BusinessFacts(
        products: state.products,
        hours: state.hours,
        delivery: delivery.trim(),
        payments: state.payments,
        location: state.location,
      ),
    );
  }

  Future<bool> setPayments(String payments) {
    return _persist(
      BusinessFacts(
        products: state.products,
        hours: state.hours,
        delivery: state.delivery,
        payments: payments.trim(),
        location: state.location,
      ),
    );
  }

  Future<bool> setLocation(String location) {
    return _persist(
      BusinessFacts(
        products: state.products,
        hours: state.hours,
        delivery: state.delivery,
        payments: state.payments,
        location: location.trim(),
      ),
    );
  }

  Future<bool> _persist(BusinessFacts next) async {
    try {
      final ok = await _store.save(next);
      if (ok) {
        state = next;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

final businessFactsNotifierProvider =
    StateNotifierProvider<BusinessFactsNotifier, BusinessFacts>((ref) {
      final notifier = BusinessFactsNotifier(ref.watch(
        businessFactsStoreProvider,
      ));
      // Carga asíncrona de arranque; la barrera global espera `ready`.
      notifier.ready;
      return notifier;
    });
