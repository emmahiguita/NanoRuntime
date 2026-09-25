// business_facts.dart
//
// QUÉ HACE:
// Snapshot estructurado y almacenamiento persistente de los hechos del negocio
// (catálogo, horarios, envíos, métodos de pago y ubicación física) para el agente comercial.
//
// CÓMO FUNCIONA:
// - Carga y guarda atómicamente la sección `business` en `AutomationDbStoreClient` (SQLite).
// - Re-exporta `business_product.dart` y `business_facts_builder.dart` manteniendo retrocompatibilidad.
// - Aplica fail-closed: ante datos corruptos inicia con hechos limpios para no inducir alucinaciones.
//
// POR QUÉ:
// Aplica Clean Architecture y SOLID reduciendo el archivo a < 100 líneas con responsabilidades delimitadas.

library;

import 'dart:convert';

import '../storage/automation_db_store_client.dart';
import 'business_facts_builder.dart';
import 'business_product.dart';

export 'business_facts_builder.dart';
export 'business_product.dart';

/// Snapshot completo de hechos comerciales del negocio.
final class BusinessFacts {
  final String businessName;
  final List<BusinessProduct> products;
  final String hours;
  final String delivery;
  final String payments;
  final String location;

  const BusinessFacts({
    this.businessName = '',
    this.products = const [],
    this.hours = '',
    this.delivery = '',
    this.payments = '',
    this.location = '',
  });

  bool get isEmpty =>
      businessName.trim().isEmpty &&
      products.isEmpty &&
      hours.trim().isEmpty &&
      delivery.trim().isEmpty &&
      payments.trim().isEmpty &&
      location.trim().isEmpty;

  factory BusinessFacts.fromJson(Map<String, dynamic> json) => BusinessFacts(
    businessName: (json['businessName'] as String?) ?? '',
    products: [
      for (final p in (json['products'] as List?) ?? const [])
        if (p is Map) BusinessProduct.fromJson(p.cast<String, dynamic>()),
    ],
    hours: (json['hours'] as String?) ?? '',
    delivery: (json['delivery'] as String?) ?? '',
    payments: (json['payments'] as String?) ?? '',
    location: (json['location'] as String?) ?? '',
  );

  Map<String, Object?> toJson() => {
    'businessName': businessName,
    'products': [for (final p in products) p.toJson()],
    'hours': hours,
    'delivery': delivery,
    'payments': payments,
    'location': location,
  };

  /// Bloque autorizado para el prompt (todo el catálogo). Vacío → ''.
  String formatPromptBlock() => buildBusinessBlock(
    businessName: businessName,
    products: products,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
  );

  /// Copia segura para que una edición no elimine otros hechos configurados.
  BusinessFacts copyWith({
    String? businessName,
    List<BusinessProduct>? products,
    String? hours,
    String? delivery,
    String? payments,
    String? location,
  }) => BusinessFacts(
    businessName: businessName ?? this.businessName,
    products: products ?? this.products,
    hours: hours ?? this.hours,
    delivery: delivery ?? this.delivery,
    payments: payments ?? this.payments,
    location: location ?? this.location,
  );
}

/// Almacenamiento persistente transaccional de hechos en SQLite (AutomationStoreDb).
class BusinessFactsStore {
  const BusinessFactsStore();

  static const section = 'business';

  Future<BusinessFacts> load() async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(section);
      if (raw == null || raw.isEmpty) return const BusinessFacts();
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return BusinessFacts.fromJson(map);
    } on Object {
      // Sección corrupta: empezar sin datos (fail-closed, honesto).
      return const BusinessFacts();
    }
  }

  Future<bool> save(BusinessFacts facts) => AutomationDbStoreClient.instance
      .putSection(section, jsonEncode(facts.toJson()));
}
