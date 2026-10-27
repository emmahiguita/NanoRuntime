// commercial_order.dart
//
// QUÉ HACE:
// Entidad inmutable de Pedido Comercial (CommercialOrder) en Nano Negocio.
//
// CÓMO FUNCIONA:
// - Registra ID de orden, referencia única, lista de CommercialCartItem,
//   monto total, dirección de entrega opcional, estado y fecha de creación.
//
// POR QUÉ:
// Separa el concepto de Pedido como entidad de dominio propia e independiente del transporte.

library;

import '../state/commercial_cart_item.dart';

enum OrderStatus {
  created,
  pendingPayment,
  paid,
  shipped,
  delivered,
  cancelled,
}

final class CommercialOrder {
  final String id;
  final String orderReference;
  final String conversationId;
  final List<CommercialCartItem> items;
  final double totalAmount;
  final String? deliveryAddress;
  final OrderStatus status;
  final DateTime createdAt;

  const CommercialOrder({
    required this.id,
    required this.orderReference,
    required this.conversationId,
    required this.items,
    required this.totalAmount,
    this.deliveryAddress,
    this.status = OrderStatus.created,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderReference': orderReference,
    'conversationId': conversationId,
    'items': [for (final i in items) i.toJson()],
    'totalAmount': totalAmount,
    if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CommercialOrder.fromJson(Map<String, dynamic> json) =>
      CommercialOrder(
        id: (json['id'] as String?) ?? '',
        orderReference: (json['orderReference'] as String?) ?? '',
        conversationId: (json['conversationId'] as String?) ?? '',
        items: [
          for (final i in (json['items'] as List?) ?? const [])
            if (i is Map) CommercialCartItem.fromJson(i.cast<String, dynamic>()),
        ],
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        deliveryAddress: json['deliveryAddress'] as String?,
        status: _parseStatus(json['status'] as String?),
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );

  static OrderStatus _parseStatus(String? name) {
    if (name == null) return OrderStatus.created;
    for (final s in OrderStatus.values) {
      if (s.name == name) return s;
    }
    return OrderStatus.created;
  }
}
