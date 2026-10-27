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
import 'business_profile.dart';
import 'business_product.dart';
import 'business_response_templates.dart';

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
  final BusinessProfile profile;
  // Las personalizaciones viven junto al negocio y migran con su JSON existente.
  final BusinessResponseTemplates responseTemplates;

  const BusinessFacts({
    this.businessName = '',
    this.products = const [],
    this.hours = '',
    this.delivery = '',
    this.payments = '',
    this.location = '',
    this.profile = const BusinessProfile(),
    this.responseTemplates = const BusinessResponseTemplates(),
  });

  bool get isEmpty =>
      businessName.trim().isEmpty &&
      products.isEmpty &&
      hours.trim().isEmpty &&
      delivery.trim().isEmpty &&
      payments.trim().isEmpty &&
      location.trim().isEmpty &&
      !profile.isConfigured &&
      responseTemplates.phrases.isEmpty;

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
    profile: json['profile'] is Map
        ? BusinessProfile.fromJson(
            (json['profile'] as Map).cast<String, dynamic>(),
          )
        : const BusinessProfile(),
    responseTemplates: BusinessResponseTemplates.fromJson(
      json['responseTemplates'],
    ),
  );

  Map<String, Object?> toJson() => {
    'businessName': businessName,
    'products': [for (final p in products) p.toJson()],
    'hours': hours,
    'delivery': delivery,
    'payments': payments,
    'location': location,
    'profile': profile.toJson(),
    'responseTemplates': responseTemplates.toJson(),
  };

  /// Bloque autorizado para el prompt (todo el catálogo). Vacío → ''.
  String formatPromptBlock() => buildBusinessBlock(
    businessName: businessName,
    products: products,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
    profile: profile,
  );

  /// Copia segura para que una edición no elimine otros hechos configurados.
  BusinessFacts copyWith({
    String? businessName,
    List<BusinessProduct>? products,
    String? hours,
    String? delivery,
    String? payments,
    String? location,
    BusinessProfile? profile,
    BusinessResponseTemplates? responseTemplates,
  }) => BusinessFacts(
    businessName: businessName ?? this.businessName,
    products: products ?? this.products,
    hours: hours ?? this.hours,
    delivery: delivery ?? this.delivery,
    payments: payments ?? this.payments,
    location: location ?? this.location,
    profile: profile ?? this.profile,
    responseTemplates: responseTemplates ?? this.responseTemplates,
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
