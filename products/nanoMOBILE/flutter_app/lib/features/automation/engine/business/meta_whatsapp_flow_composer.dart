// meta_whatsapp_flow_composer.dart
//
// QUÉ HACE:
// Orquesta la generación de WhatsApp Flows oficiales a partir del catálogo y carrito
// del negocio, y aplica las respuestas estructuradas (`nfm_reply`) al estado comercial.
//
// CÓMO FUNCIONA:
// - [buildCheckoutFlow] convierte el estado del carrito o producto en foco en un
//   [MetaWhatsAppFlowRequest] listo para ser enviado por Meta Cloud API.
// - [applySubmission] procesa un [MetaWhatsAppFlowSubmission] validando el producto,
//   actualizando cantidades en el carrito, limpiando slots pendientes y avanzando
//   el embudo a [CommercialFunnelStage.paymentPending].
//
// POR QUÉ:
// Sustituye los formularios manuales por texto libre en Negocio (Punto 6) con una
// transición determinista y libre de fricción para el comprador.

library;

import 'business_facts.dart';
import 'meta_whatsapp_flow_models.dart';
import 'state/commercial_cart_item.dart';
import 'state/commercial_conversation_state.dart';
import 'state/commercial_funnel_stage.dart';

final class MetaWhatsAppFlowComposer {
  const MetaWhatsAppFlowComposer();

  /// Construye un Flow interactivo oficial para completar pedido o seleccionar producto.
  MetaWhatsAppFlowRequest buildCheckoutFlow({
    required String recipientPhone,
    required String flowId,
    required CommercialConversationState state,
    required BusinessFacts facts,
  }) {
    final availableProducts = facts.products
        .where((p) => p.isAvailable)
        .take(20)
        .map(
          (p) => {
            'id': p.id,
            'title': p.name,
            'price': p.price,
            if (p.variants.isNotEmpty) 'variants': p.variants,
          },
        )
        .toList(growable: false);

    final screen = state.cart.isNotEmpty || state.focusedProductId != null
        ? MetaWhatsAppFlowScreen.orderCheckout
        : MetaWhatsAppFlowScreen.productSelection;

    final businessTitle = facts.businessName.trim().isEmpty
        ? 'Pedido Oficial'
        : facts.businessName.trim();

    return MetaWhatsAppFlowRequest(
      recipientPhone: recipientPhone,
      flowId: flowId,
      flowToken: 'nano_${state.conversationId}_${state.factsVersion}',
      headerText: businessTitle,
      bodyText: state.cart.isNotEmpty
          ? 'Confirma tu dirección y método de pago para completar tu pedido.'
          : 'Selecciona tus productos y datos de envío en el formulario interactivo.',
      ctaLabel: state.cart.isNotEmpty ? 'Completar pedido' : 'Ver formulario',
      screen: screen,
      initialData: {
        'conversation_id': state.conversationId,
        if (state.focusedProductId != null)
          'focused_product_id': state.focusedProductId,
        'cart_total': state.cartTotal,
        'catalog_items': availableProducts,
      },
    );
  }

  /// Aplica la respuesta estructurada de un WhatsApp Flow al estado comercial.
  CommercialConversationState applySubmission({
    required CommercialConversationState currentState,
    required MetaWhatsAppFlowSubmission submission,
    required BusinessFacts facts,
  }) {
    var updatedCart = List<CommercialCartItem>.from(currentState.cart);
    final prodId = submission.selectedProductId ?? currentState.focusedProductId;

    if (prodId != null && prodId.isNotEmpty) {
      final matched = facts.products
          .where((p) => p.id == prodId && p.isAvailable)
          .firstOrNull;
      if (matched != null) {
        final qty = (submission.quantity ?? 1).clamp(1, 999);
        final existingIdx = updatedCart.indexWhere(
          (item) => item.productId == matched.id,
        );
        final cartItem = CommercialCartItem(
          productId: matched.id,
          productName: matched.name,
          unitPrice: matched.price.toDouble(),
          quantity: qty,
        );
        if (existingIdx >= 0) {
          updatedCart[existingIdx] = cartItem;
        } else {
          updatedCart.add(cartItem);
        }
      }
    }

    final hasDeliveryData =
        (submission.deliveryAddress?.isNotEmpty ?? false) ||
        (submission.customerName?.isNotEmpty ?? false);

    final nextStage = updatedCart.isNotEmpty && hasDeliveryData
        ? CommercialFunnelStage.paymentPending
        : updatedCart.isNotEmpty
        ? CommercialFunnelStage.checkout
        : currentState.stage;

    return currentState.copyWith(
      stage: nextStage,
      cart: List.unmodifiable(updatedCart),
      pendingSlot: null,
      lastInteraction: DateTime.now(),
    );
  }
}
