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

  Future<void> upsertProduct(BusinessProduct product) async {
    final next = BusinessFacts(
      products: [
        for (final p in state.products)
          if (p.id != product.id) p,
        product,
      ],
      hours: state.hours,
      delivery: state.delivery,
    );
    await _persist(next);
  }

  Future<void> removeProduct(String id) async {
    await _persist(
      BusinessFacts(
        products: [
          for (final p in state.products)
            if (p.id != id) p,
        ],
        hours: state.hours,
        delivery: state.delivery,
      ),
    );
  }

  Future<void> setHours(String hours) async {
    await _persist(
      BusinessFacts(
        products: state.products,
        hours: hours.trim(),
        delivery: state.delivery,
      ),
    );
  }

  Future<void> setDelivery(String delivery) async {
    await _persist(
      BusinessFacts(
        products: state.products,
        hours: state.hours,
        delivery: delivery.trim(),
      ),
    );
  }

  Future<void> _persist(BusinessFacts next) async {
    state = next;
    await _store.save(next);
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
