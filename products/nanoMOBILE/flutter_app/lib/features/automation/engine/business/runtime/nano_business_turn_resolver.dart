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
import '../business_text_matcher.dart';
import '../state/commercial_cart_item.dart';
import '../state/commercial_conversation_state.dart';
import '../state/commercial_funnel_stage.dart';
import '../validation/business_validation_result.dart';

class NanoBusinessTurnResolver {
  const NanoBusinessTurnResolver();

  CommercialStructuredAction? resolveHeuristicAction(
    String text,
    BusinessFacts facts,
    CommercialConversationState state,
  ) {
    // Normaliza acentos y usa palabras completas: «ahora» no es «hora».
    final lower = normalizeText(text);
    bool has(String pattern) => RegExp('\\b(?:$pattern)\\b').hasMatch(lower);
    // Las solicitudes sensibles se evalúan antes que las consultas informativas.
    if (has('comprobante|ya pague|transferi')) {
      return const PaymentClaimAction();
    }
    if (has('humano|asesor|persona')) {
      return const EscalateToHumanAction(
        reason: 'Solicitud de atención humana',
      );
    }
    if (has('precio|cuesta|vale')) {
      final matched = matchProductInText(lower, facts);
      return PriceQueryAction(
        productId: matched ?? state.focusedProductId ?? '',
      );
    }
    if (has('stock|disponible|disponibles|quedan')) {
      final matched = matchProductInText(lower, facts);
      return StockQueryAction(
        productId: matched ?? state.focusedProductId ?? '',
      );
    }
    if (has('horario|horarios|abren|hora')) {
      return const PolicyQueryAction(policyTopic: 'hours');
    }
    if (has('envio|envios|domicilio|entrega')) {
      return const PolicyQueryAction(policyTopic: 'delivery');
    }
    if (has('pago|pagos|tarjeta|transferencia')) {
      return const PolicyQueryAction(policyTopic: 'payments');
    }
    if (has('ubicacion|direccion')) {
      return const PolicyQueryAction(policyTopic: 'location');
    }
    if (has('catalogo|productos|venden')) {
      return const CatalogQueryAction();
    }
    // No inventa una intención de catálogo para cualquier mensaje.
    return null;
  }

  String? matchProductInText(String text, BusinessFacts facts) {
    for (final p in facts.products) {
      if (!p.isAvailable) continue;
      final sku = normalizeText(p.sku ?? '');
      if (text.contains(normalizeText(p.name)) ||
          (sku.isNotEmpty && text.contains(sku))) {
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
        currentCart.add(
          CommercialCartItem(
            productId: p.id,
            productName: p.name,
            unitPrice: p.price.toDouble(),
            quantity: action.quantity,
          ),
        );
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
