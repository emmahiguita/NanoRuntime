// business_product.dart
//
// QUÉ HACE:
// Modelo inmutable de Producto Comercial para el catálogo del agente de ventas/negocios.
// Representa SKU, variantes, categorías, precio, stock y estado de disponibilidad.
//
// CÓMO FUNCIONA:
// - Serializa y deserializa a JSON con validación de tipos y nulos segura.
// - Genera formato monetario legible en miles (`priceLabel`) sin dependencias pesadas.
// - Provee `promptLine()` para inyección determinista en prompts de modelos locales sin alucinación.
//
// POR QUÉ:
// Aplica SOLID (Single Responsibility Principle) desacoplando la entidad del producto
// del contenedor global de hechos del negocio y manteniendo archivos estrictamente menores a 200 líneas.

library;

/// Producto del catálogo comercial.
/// [price] en moneda local, [stock] null = sin dato verificado de stock.
/// [details] y [variants] permiten resolver referencias coloquiales como "el negro 256GB".
final class BusinessProduct {
  final String id;
  final String name;
  final String details;
  final int price;
  final int? stock;
  final String? sku;
  final String? category;
  final bool isAvailable;
  final List<String> variants;
  final String? imagePath;
  final bool isManualEdit;

  const BusinessProduct({
    required this.id,
    required this.name,
    required this.details,
    required this.price,
    this.stock,
    this.sku,
    this.category,
    this.isAvailable = true,
    this.variants = const [],
    this.imagePath,
    this.isManualEdit = false,
  });

  /// Etiqueta de precio formateada con separadores de miles ($XX.XXX).
  String get priceLabel => _formatThousands(price);

  BusinessProduct copyWith({
    String? id,
    String? name,
    String? details,
    int? price,
    int? stock,
    String? sku,
    String? category,
    bool? isAvailable,
    List<String>? variants,
    String? imagePath,
    bool? isManualEdit,
  }) {
    return BusinessProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      details: details ?? this.details,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      variants: variants ?? this.variants,
      imagePath: imagePath ?? this.imagePath,
      isManualEdit: isManualEdit ?? this.isManualEdit,
    );
  }

  factory BusinessProduct.fromJson(Map<String, dynamic> json) => BusinessProduct(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    details: (json['details'] as String?) ?? '',
    price: (json['price'] as num?)?.toInt() ?? 0,
    stock: (json['stock'] as num?)?.toInt(),
    sku: json['sku'] as String?,
    category: json['category'] as String?,
    isAvailable: json['isAvailable'] != false,
    variants: (json['variants'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    imagePath: json['imagePath'] as String?,
    isManualEdit: json['isManualEdit'] == true,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'details': details,
    'price': price,
    if (stock != null) 'stock': stock,
    if (sku != null && sku!.isNotEmpty) 'sku': sku,
    if (category != null && category!.isNotEmpty) 'category': category,
    'isAvailable': isAvailable,
    if (variants.isNotEmpty) 'variants': variants,
    if (imagePath != null && imagePath!.isNotEmpty) 'imagePath': imagePath,
    if (isManualEdit) 'isManualEdit': true,
  };

  /// Línea compacta formateada para la memoria y contexto del agente de ventas.
  String promptLine() {
    if (!isAvailable) {
      return '- $name: $priceLabel (NO DISPONIBLE TEMPORALMENTE / PAUSADO)';
    }
    final buffer = StringBuffer();
    if (category != null && category!.trim().isNotEmpty) {
      buffer.write('[${category!.trim()}] ');
    }
    buffer.write(name);
    final variantParts = <String>[];
    if (details.trim().isNotEmpty) {
      variantParts.add(details.trim());
    }
    if (variants.isNotEmpty) {
      variantParts.add('variantes: ${variants.join(", ")}');
    }
    if (sku != null && sku!.trim().isNotEmpty) {
      variantParts.add('SKU: ${sku!.trim()}');
    }
    if (variantParts.isNotEmpty) {
      buffer.write(' (${variantParts.join(" · ")})');
    }
    final stockLabel = stock == null
        ? 'stock no confirmado (verificar disponibilidad)'
        : (stock == 0 ? 'agotado (sin stock disponible)' : 'stock $stock disponible');
    buffer.write(': $priceLabel ($stockLabel)');
    return buffer.toString();
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
