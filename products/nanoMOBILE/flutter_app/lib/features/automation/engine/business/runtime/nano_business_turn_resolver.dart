// nano_business_turn_resolver.dart
//
// QUÉ HACE:
// Helper especializado para resolución heurística de intenciones comerciales,
// coincidencia de productos en texto y transiciones del estado del carrito.
//
// CÓMO FUNCIONA:
// - Descompone el texto del cliente para identificar intenciones (precio, stock, políticas).
// - Realiza coincidencia determinista con el catálogo oficial de BusinessFacts.
// - Actualiza el carrito y la etapa del embudo comercial (CommercialConversationState).
//
// POR QUÉ:
// Mantiene nano_business_runtime.dart limpio y estrictamente menor a 200 líneas (SOLID).

library;

import '../actions/commercial_structured_action.dart';
import '../business_facts.dart';
import '../state/commercial_cart_item.dart';
import '../state/commercial_conversation_state.dart';
import '../state/commercial_funnel_stage.dart';
import '../validation/business_validation_result.dart';

class NanoBusinessTurnResolver {
  const NanoBusinessTurnResolver();

  CommercialStructuredAction resolveHeuristicAction(
    String text,
    BusinessFacts facts,
    CommercialConversationState state,
  ) {
    final lower = text.toLowerCase().trim();
    if (lower.contains('precio') || lower.contains('cuesta') || lower.contains('vale')) {
      final matched = matchProductInText(lower, facts);
      return PriceQueryAction(productId: matched ?? state.focusedProductId ?? '');
    }
    if (lower.contains('stock') || lower.contains('disponible') || lower.contains('quedan')) {
      final matched = matchProductInText(lower, facts);
      return StockQueryAction(productId: matched ?? state.focusedProductId ?? '');
    }
    if (lower.contains('horario') || lower.contains('abren') || lower.contains('hora')) {
      return const PolicyQueryAction(policyTopic: 'hours');
    }
    if (lower.contains('envio') || lower.contains('domicilio') || lower.contains('entrega')) {
      return const PolicyQueryAction(policyTopic: 'delivery');
    }
    if (lower.contains('pago') || lower.contains('tarjeta') || lower.contains('transferencia')) {
      return const PolicyQueryAction(policyTopic: 'payments');
    }
    if (lower.contains('catalogo') || lower.contains('productos') || lower.contains('venden')) {
      return const CatalogQueryAction();
    }
    if (lower.contains('comprobante') || lower.contains('ya pague') || lower.contains('transferi')) {
      return const PaymentClaimAction();
    }
    if (lower.contains('humano') || lower.contains('asesor') || lower.contains('persona')) {
      return const EscalateToHumanAction(reason: 'Solicitud explícita de asesor humano');
    }
    return const CatalogQueryAction();
  }

  String? matchProductInText(String text, BusinessFacts facts) {
    for (final p in facts.products) {
      final sku = p.sku?.toLowerCase() ?? '';
      if (text.contains(p.name.toLowerCase()) || (sku.isNotEmpty && text.contains(sku))) {
        return p.id;
      }
    }
    return null;
  }

  CommercialConversationState updateStateOnSuccess(
    CommercialConversationState state,
    CommercialStructuredAction action,
    AcceptedBusinessValidation val,
  ) {
    if (val.verifiedProduct != null) {
      final p = val.verifiedProduct!;
      if (action is AddToCartAction) {
        final currentCart = List<CommercialCartItem>.from(state.cart);
        currentCart.add(CommercialCartItem(
          productId: p.id,
          productName: p.name,
          unitPrice: p.price.toDouble(),
          quantity: action.quantity,
        ));
        return state.copyWith(
          stage: CommercialFunnelStage.cartActive,
          focusedProductId: p.id,
          cart: currentCart,
        );
      }
      return state.copyWith(
        stage: CommercialFunnelStage.interest,
        focusedProductId: p.id,
      );
    }
    return state;
  }
}
