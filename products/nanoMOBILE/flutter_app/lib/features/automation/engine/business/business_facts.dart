/// WA-BUSINESS-01 — hechos reales del negocio: catálogo, horario y envío.
///
/// Regla central del módulo: LLM sabe lenguaje, ESTE store sabe hechos. Los
/// datos viven en el AutomationStoreDb (sección `business`, whitelist Kotlin)
/// y se inyectan al prompt del borrador como bloque autorizado
/// <DATOS DEL NEGOCIO> en UNA sola pasada LLM (dos llamadas duplican el
/// prefill — inviable en hardware lento, WA-CONVERSATION-01).
///
/// Fuera del bloque el modelo no inventa: marca missingFacts/requiresAction
/// y pregunta. El refinamiento a tools transaccionales (reservas reales,
/// consultas) queda como WA-BUSINESS-02 cuando el modelo permita multi-pase.
library;

import 'dart:convert';

import '../storage/automation_db_store_client.dart';

/// Producto del catálogo. [price] en pesos (int), [stock] null = sin dato de
/// stock (el agente no lo afirma). [details] captura variante ("negro 256GB")
/// para que el modelo resuelva referencias como "el negro" contra el bloque.
final class BusinessProduct {
  final String id;
  final String name;
  final String details;
  final int price;
  final int? stock;

  const BusinessProduct({
    required this.id,
    required this.name,
    required this.details,
    required this.price,
    this.stock,
  });

  String get priceLabel => _formatThousands(price);

  factory BusinessProduct.fromJson(Map<String, dynamic> json) => BusinessProduct(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    details: (json['details'] as String?) ?? '',
    price: (json['price'] as num?)?.toInt() ?? 0,
    stock: (json['stock'] as num?)?.toInt(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'details': details,
    'price': price,
    if (stock != null) 'stock': stock,
  };

  /// Línea compacta del bloque de datos (una por producto).
  String promptLine() {
    final variant = details.trim();
    final label = variant.isEmpty ? name : '$name ($variant)';
    final stockLabel = stock == null ? 'stock no confirmado' : 'stock $stock';
    return '- $label: $priceLabel ($stockLabel)';
  }

  static String _formatThousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '\$$buffer';
  }
}

/// Snapshot completo de datos del negocio.
final class BusinessFacts {
  final List<BusinessProduct> products;
  final String hours;
  final String delivery;

  const BusinessFacts({
    this.products = const [],
    this.hours = '',
    this.delivery = '',
  });

  bool get isEmpty =>
      products.isEmpty && hours.trim().isEmpty && delivery.trim().isEmpty;

  factory BusinessFacts.fromJson(Map<String, dynamic> json) => BusinessFacts(
    products: [
      for (final p in (json['products'] as List?) ?? const [])
        if (p is Map)
          BusinessProduct.fromJson(p.cast<String, dynamic>()),
    ],
    hours: (json['hours'] as String?) ?? '',
    delivery: (json['delivery'] as String?) ?? '',
  );

  Map<String, Object?> toJson() => {
    'products': [for (final p in products) p.toJson()],
    'hours': hours,
    'delivery': delivery,
  };

  /// Bloque autorizado para el prompt (todo el catálogo). Vacío → ''.
  String formatPromptBlock() => buildBusinessBlock(
    products: products,
    hours: hours,
    delivery: delivery,
  );
}

/// UNICA fuente de formato del bloque <DATOS DEL NEGOCIO> — compartida por
/// [BusinessFacts.formatPromptBlock] (catálogo completo) y por el selector
/// de hechos (WA-BUSINESS-02, subconjunto relevante). Sin duplicado.
String buildBusinessBlock({
  required List<BusinessProduct> products,
  required String hours,
  required String delivery,
}) {
  final cleanHours = hours.trim();
  final cleanDelivery = delivery.trim();
  if (products.isEmpty && cleanHours.isEmpty && cleanDelivery.isEmpty) {
    return '';
  }
  final buffer = StringBuffer('<DATOS DEL NEGOCIO>\n');
  if (products.isNotEmpty) {
    buffer
      ..writeln('Productos en venta:')
      ..writeln(products.map((p) => p.promptLine()).join('\n'));
  }
  if (cleanHours.isNotEmpty) {
    buffer.writeln('Horario: $cleanHours');
  }
  if (cleanDelivery.isNotEmpty) {
    buffer.writeln('Envío: $cleanDelivery');
  }
  buffer.write('</DATOS DEL NEGOCIO>');
  return buffer.toString();
}

/// Persistencia de hechos (DIP). Producción = AutomationStoreDb sección
/// `business`; los tests pueden usar memoria.
class BusinessFactsStore {
  const BusinessFactsStore();

  static const section = 'business';

  Future<BusinessFacts> load() async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(section);
      if (raw == null || raw.isEmpty) return const BusinessFacts();
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final facts = BusinessFacts.fromJson(map);
      return facts;
    } on Object {
      // Sección corrupta: empezar sin datos (fail-closed, honesto).
      return const BusinessFacts();
    }
  }

  Future<bool> save(BusinessFacts facts) =>
      AutomationDbStoreClient.instance.putSection(
        section,
        jsonEncode(facts.toJson()),
      );
}
