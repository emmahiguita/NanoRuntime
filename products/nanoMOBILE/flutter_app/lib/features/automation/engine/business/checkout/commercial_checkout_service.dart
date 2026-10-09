// commercial_checkout_service.dart
//
// QUÉ HACE:
// Servicio para generación de resúmenes de pedidos, instrucciones de pago
// y enlaces dinámicos de cobro (Checkout).
//
// CÓMO FUNCIONA:
// - Toma los ítems del carrito y las políticas de pago de BusinessFacts.
// - Genera un código de referencia único (`ORD-XXXXX`).
// - Produce el mensaje formateado de cobro para enviar por chat al cliente.
//
// POR QUÉ:
// Formaliza la transición del carrito al pago pendiente en la máquina de estados.

library;

import '../business_facts.dart';
import '../state/commercial_cart_item.dart';
import '../state/commercial_conversation_state.dart';
import '../state/commercial_funnel_stage.dart';

final class CheckoutOrderResult {
  final String orderReference;
  final double totalAmount;
  final String checkoutMessage;
  final CommercialConversationState updatedState;

  const CheckoutOrderResult({
    required this.orderReference,
    required this.totalAmount,
    required this.checkoutMessage,
    required this.updatedState,
  });
}

class CommercialCheckoutService {
  final BusinessFacts facts;

  const CommercialCheckoutService(this.facts);

  /// Genera la orden y el mensaje de checkout con instrucciones de pago.
  CheckoutOrderResult createCheckout({
    required CommercialConversationState state,
    String? deliveryAddress,
  }) {
    final orderRef = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final total = state.cartTotal;
    final buffer = StringBuffer('🛒 *Resumen de tu Pedido* ($orderRef)\n\n');

    for (final item in state.cart) {
      buffer.writeln('• ${item.quantity}x ${item.productName} - \$${item.subtotal.toStringAsFixed(0)}');
    }
    buffer.writeln('\n*Total a Pagar:* \$${total.toStringAsFixed(0)}');

    if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) {
      buffer.writeln('📍 *Dirección de Entrega:* $deliveryAddress');
    }

    if (facts.payments.isNotEmpty) {
      buffer.writeln('\n💳 *Medios de Pago Disponibles:*\n${facts.payments}');
    }

    buffer.writeln('\n_Por favor realiza el pago e indícanos el comprobante por este medio para despachar tu orden._');

    final updated = state.copyWith(
      stage: CommercialFunnelStage.paymentPending,
      pendingSlot: null,
      lastInteraction: DateTime.now(),
    );

    return CheckoutOrderResult(
      orderReference: orderRef,
      totalAmount: total,
      checkoutMessage: buffer.toString().trim(),
      updatedState: updated,
    );
  }
}
