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
  Future<void> _writeTail = Future<void>.value();

  /// Futuro compartido de la carga (idempotente — patrón del módulo).
  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      final loaded = await _store.load();
      if (!mounted) return;
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
  Future<bool> loadPreset(BusinessFacts preset) => _persist(
    (current) => preset.copyWith(responseTemplates: current.responseTemplates),
  );

  /// Aplica únicamente el contrato operativo; conserva todos los datos reales.
  Future<bool> setProfile(BusinessProfile profile) =>
      _persist((current) => current.copyWith(profile: profile));

  /// Persiste frases personalizadas sin modificar catálogo ni hechos del negocio.
  Future<bool> setResponseTemplates(BusinessResponseTemplates templates) =>
      _persist((current) => current.copyWith(responseTemplates: templates));

  Future<bool> setBusinessName(String name) =>
      _persist((current) => current.copyWith(businessName: name.trim()));

  Future<bool> upsertProduct(BusinessProduct product) {
    return _persist(
      (current) => current.copyWith(
        products: _mergeProducts(current.products, [product]),
      ),
    );
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
      return _persist(
        (current) => current.copyWith(products: _mergeProducts([], incoming)),
      );
    }
    return _persist(
      (current) => current.copyWith(
        products: _mergeProducts(current.products, incoming),
      ),
    );
  }

  Future<bool> removeProduct(String id) {
    return _persist(
      (current) => current.copyWith(
        products: [
          for (final p in current.products)
            if (p.id != id) p,
        ],
      ),
    );
  }

  Future<bool> setHours(String hours) {
    return _persist((current) => current.copyWith(hours: hours.trim()));
  }

  Future<bool> setDelivery(String delivery) {
    return _persist((current) => current.copyWith(delivery: delivery.trim()));
  }

  Future<bool> setPayments(String payments) {
    return _persist((current) => current.copyWith(payments: payments.trim()));
  }

  Future<bool> setLocation(String location) {
    return _persist((current) => current.copyWith(location: location.trim()));
  }

  /// Serializa lectura-modificación-escritura sobre el estado más reciente.
  /// Espera hidratación y evita que guardar frases borre un producto concurrente.
  Future<bool> _persist(BusinessFacts Function(BusinessFacts) update) {
    final operation = _writeTail.then((_) async {
      try {
        await ready;
        if (!mounted) return false;
        final next = update(state);
        if (!await _store.save(next)) return false;
        if (mounted) state = next;
        return true;
      } catch (_) {
        return false;
      }
    });
    _writeTail = operation.then<void>((_) {}, onError: (_) {});
    return operation;
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
