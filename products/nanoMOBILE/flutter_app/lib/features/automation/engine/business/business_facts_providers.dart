/// WA-BUSINESS-01 — providers de hechos del negocio. La carga entra en la
/// barrera global de hidratación (automationStoresHydratedProvider) y el
/// bloque se lee EN VIVO en cada borrador (editar catálogo aplica desde el
/// siguiente mensaje, sin reconstruir el writer).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_facts.dart';
import 'business_response_templates.dart';
import 'business_profile.dart';
import 'business_presets.dart';
import 'business_text_matcher.dart';

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
      final loaded = await _store.load();
      final cleanProducts = _mergeProducts([], loaded.products);
      final profile = loaded.profile.isConfigured
          ? loaded.profile
          : customPreset.profile;
      state = loaded.copyWith(products: cleanProducts, profile: profile);
      // Migra perfil vacío y repara duplicados históricos una sola vez.
      if (cleanProducts.length != loaded.products.length ||
          !loaded.profile.isConfigured) {
        await _store.save(state);
      }
    } on Object {
      // Sin datos: estado vacío honesto.
    }
  }

  Future<void> reload() async {
    _loading = null;
    await ready;
  }

  /// Cambiar de rubro conserva frases personalizadas por el propietario.
  Future<bool> loadPreset(BusinessFacts preset) =>
      _persist(preset.copyWith(responseTemplates: state.responseTemplates));

  /// Aplica únicamente el contrato operativo; conserva todos los datos reales.
  Future<bool> setProfile(BusinessProfile profile) =>
      _persist(state.copyWith(profile: profile));

  /// Persiste frases personalizadas sin modificar catálogo ni hechos del negocio.
  Future<bool> setResponseTemplates(BusinessResponseTemplates templates) =>
      _persist(state.copyWith(responseTemplates: templates));

  Future<bool> setBusinessName(String name) =>
      _persist(state.copyWith(businessName: name.trim()));

  Future<bool> upsertProduct(BusinessProduct product) {
    final next = state.copyWith(
      products: _mergeProducts(state.products, [product]),
    );
    return _persist(next);
  }

  /// QUÉ HACE:
  /// Importa un lote de productos al catálogo comercial de Nano.
  /// CÓMO FUNCIONA:
  /// Si [replaceAll] es true, reemplaza todo el catálogo; si es false, fusiona
  /// o actualiza los productos existentes por ID o nombre.
  /// POR QUÉ:
  /// Permite sincronizar inventarios masivos desde Excel/CSV/SQL de forma transaccional.
  Future<bool> importProducts(
    List<BusinessProduct> incoming, {
    bool replaceAll = false,
  }) {
    if (replaceAll) {
      return _persist(state.copyWith(products: _mergeProducts([], incoming)));
    }
    return _persist(
      state.copyWith(products: _mergeProducts(state.products, incoming)),
    );
  }

  Future<bool> removeProduct(String id) {
    return _persist(
      state.copyWith(
        products: [
          for (final p in state.products)
            if (p.id != id) p,
        ],
      ),
    );
  }

  Future<bool> setHours(String hours) {
    return _persist(state.copyWith(hours: hours.trim()));
  }

  Future<bool> setDelivery(String delivery) {
    return _persist(state.copyWith(delivery: delivery.trim()));
  }

  Future<bool> setPayments(String payments) {
    return _persist(state.copyWith(payments: payments.trim()));
  }

  Future<bool> setLocation(String location) {
    return _persist(state.copyWith(location: location.trim()));
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

  /// Fusiona por ID o nombre canónico para impedir productos visualmente duplicados.
  List<BusinessProduct> _mergeProducts(
    List<BusinessProduct> current,
    List<BusinessProduct> incoming,
  ) {
    final merged = [...current];
    for (final candidate in incoming) {
      final nameKey = normalizeText(candidate.name.trim());
      if (candidate.id.trim().isEmpty || nameKey.isEmpty) continue;
      final index = merged.indexWhere(
        (item) =>
            item.id == candidate.id ||
            normalizeText(item.name.trim()) == nameKey,
      );
      if (index < 0) {
        merged.add(candidate);
      } else {
        // El ID durable evita romper referencias creadas antes de una importación.
        merged[index] = candidate.copyWith(id: merged[index].id);
      }
    }
    return List.unmodifiable(merged);
  }
}

final businessFactsNotifierProvider =
    StateNotifierProvider<BusinessFactsNotifier, BusinessFacts>((ref) {
      final notifier = BusinessFactsNotifier(
        ref.watch(businessFactsStoreProvider),
      );
      // Carga asíncrona de arranque; la barrera global espera `ready`.
      notifier.ready;
      return notifier;
    });
