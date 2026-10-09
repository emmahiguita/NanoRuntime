// commercial_cart_item.dart
//
// QUÉ HACE:
// Modelo inmutable para elementos dentro del carrito de compras conversacional.
//
// CÓMO FUNCIONA:
// - Almacena ID de producto, nombre, precio unitario, cantidad y variante.
// - Serialización JSON completa para persistencia en SQLite.
//
// POR QUÉ:
// Separa los ítems del carrito como entidad de dominio propia.

library;

final class CommercialCartItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final String? variant;
  final String currency;

  const CommercialCartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
    this.variant,
    this.currency = 'USD',
  });

  double get subtotal => unitPrice * quantity;

  CommercialCartItem copyWith({
    int? quantity,
    String? variant,
  }) => CommercialCartItem(
    productId: productId,
    productName: productName,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
    variant: variant ?? this.variant,
    currency: currency,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'unitPrice': unitPrice,
    'quantity': quantity,
    if (variant != null) 'variant': variant,
    'currency': currency,
  };

  factory CommercialCartItem.fromJson(Map<String, dynamic> json) =>
      CommercialCartItem(
        productId: (json['productId'] as String?) ?? '',
        productName: (json['productName'] as String?) ?? '',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        variant: json['variant'] as String?,
        currency: (json['currency'] as String?) ?? 'USD',
      );
}
