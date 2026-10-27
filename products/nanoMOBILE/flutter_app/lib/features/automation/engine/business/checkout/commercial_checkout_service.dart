// commercial_checkout_service.dart
//
// QUÉ HACE:
// Servicio para creación de órdenes de compra y resúmenes de checkout agnósticos al canal.
//
// CÓMO FUNCIONA:
// - Transforma el carrito activo en un `CommercialOrder` inmutable.
// - Produce un resumen de texto universal (`customerSummary`) sin acoplamiento a WhatsApp u otra app.
// - Transiciona el estado comercial a `paymentPending` sin realizar envíos directos.
//
// POR QUÉ:
// Separa estrictamente la creación del checkout (dominio) del despacho por mensajería (adaptadores).

library;

import '../business_facts.dart';
import '../state/commercial_conversation_state.dart';
import '../state/commercial_funnel_stage.dart';
import 'commercial_order.dart';

final class CommercialCheckoutResult {
  final CommercialOrder order;
  final String customerSummary;
  final CommercialConversationState nextState;

  const CommercialCheckoutResult({
    required this.order,
    required this.customerSummary,
    required this.nextState,
  });
}

class CommercialCheckoutService {
  final BusinessFacts facts;

  const CommercialCheckoutService(this.facts);

  /// Genera la orden y el resumen de checkout agnóstico al canal.
  CommercialCheckoutResult createCheckout({
    required CommercialConversationState state,
    String? deliveryAddress,
  }) {
    final orderRef = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final total = state.cartTotal;

    final order = CommercialOrder(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
      orderReference: orderRef,
      conversationId: state.conversationId,
      items: List.from(state.cart),
      totalAmount: total,
      deliveryAddress: deliveryAddress,
      status: OrderStatus.pendingPayment,
      createdAt: DateTime.now(),
    );

    final buffer = StringBuffer('Resumen del Pedido ($orderRef)\n\n');
    for (final item in state.cart) {
      buffer.writeln('• ${item.quantity}x ${item.productName} - \$${item.subtotal.toStringAsFixed(0)}');
    }
    buffer.writeln('\nTotal a Pagar: \$${total.toStringAsFixed(0)}');

    if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) {
      buffer.writeln('Dirección de Entrega: $deliveryAddress');
    }

    if (facts.payments.isNotEmpty) {
      buffer.writeln('\nMétodos de Pago Disponibles:\n${facts.payments}');
    }

    buffer.writeln('\nPor favor comparte el comprobante una vez realizado el pago para confirmar tu orden.');

    final updatedState = state.copyWith(
      stage: CommercialFunnelStage.paymentPending,
      pendingSlot: null,
      lastInteraction: DateTime.now(),
    );

    return CommercialCheckoutResult(
      order: order,
      customerSummary: buffer.toString().trim(),
      nextState: updatedState,
    );
  }
}
