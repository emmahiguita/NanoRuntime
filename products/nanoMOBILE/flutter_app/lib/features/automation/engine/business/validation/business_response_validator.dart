// business_response_validator.dart
//
// QUÉ HACE:
// Validador de verdad post-modelo (Truth Boundary). Evalúa cada acción estructurada
// contra los hechos reales del negocio (BusinessFacts) antes de generar cualquier texto.
//
// CÓMO FUNCIONA:
// - Busca los productos por ID o SKU directamente en la memoria inmutable de BusinessFacts.
// - Reemplaza cualquier dato propuesto por el valor verdadero de la base de datos local.
// - Ante reclamos de pago o acciones de riesgo, escala inmediatamente a validación humana.
//
// POR QUÉ:
// Garantiza la política de Cero-Alucinación: un modelo nunca puede inventar un precio,
// stock o descuento, porque este validador reconstruye la respuesta final con datos verificados.

library;

import '../actions/commercial_structured_action.dart';
import '../business_facts.dart';
import 'business_validation_result.dart';

class BusinessResponseValidator {
  final BusinessFacts facts;

  const BusinessResponseValidator(this.facts);

  /// Valida y resuelve una acción estructurada contra los hechos del negocio.
  BusinessValidationResult validate(CommercialStructuredAction action) {
    return switch (action) {
      PriceQueryAction a => _validatePriceQuery(a),
      StockQueryAction a => _validateStockQuery(a),
      CatalogQueryAction a => _validateCatalogQuery(a),
      AddToCartAction a => _validateAddToCart(a),
      PaymentClaimAction a => _validatePaymentClaim(a),
      PolicyQueryAction a => _validatePolicyQuery(a),
      EscalateToHumanAction a => _validateEscalation(a),
    };
  }

  BusinessValidationResult _validatePriceQuery(PriceQueryAction a) {
    final product = _findProduct(a.productId);
    if (product == null) {
      return RejectedBusinessValidation(
        reason: 'Producto no encontrado: ${a.productId}',
        fallbackReply: 'No encontré ese producto en nuestro catálogo actual. '
            '¿Deseas que te comparta los productos disponibles?',
      );
    }

    final reply = 'El ${product.name} tiene un precio de ${product.priceLabel}.';
    return AcceptedBusinessValidation(
      formattedReply: reply,
      verifiedProduct: product,
      suggestions: ['¿Cómo comprar?', 'Ver detalles', 'Consultar stock'],
    );
  }

  BusinessValidationResult _validateStockQuery(StockQueryAction a) {
    final product = _findProduct(a.productId);
    if (product == null) {
      return RejectedBusinessValidation(
        reason: 'Producto no encontrado para stock: ${a.productId}',
        fallbackReply: 'No localicé ese producto en inventario. ¿Me confirmas el nombre exacto?',
      );
    }

    final stock = product.stock ?? 0;
    final hasStock = stock > 0;
    final reply = hasStock
        ? 'Sí, tenemos disponible el ${product.name} (quedan $stock unidades) a ${product.priceLabel}.'
        : 'Actualmente el ${product.name} se encuentra agotado. ¿Te gustaría consultar un producto similar?';

    return AcceptedBusinessValidation(
      formattedReply: reply,
      verifiedProduct: product,
      suggestions: hasStock ? ['Comprar', 'Métodos de pago'] : ['Ver catálogo'],
    );
  }

  BusinessValidationResult _validateCatalogQuery(CatalogQueryAction a) {
    if (facts.products.isEmpty) {
      return const RejectedBusinessValidation(
        reason: 'Catálogo vacío',
        fallbackReply: 'En este momento estamos actualizando nuestro catálogo. '
            'Un asesor te atenderá en breve.',
      );
    }

    final targetCat = a.category?.toLowerCase();
    final filtered = targetCat != null && targetCat.isNotEmpty
        ? facts.products.where((p) => (p.category ?? '').toLowerCase() == targetCat).toList()
        : facts.products;

    final targetList = filtered.isNotEmpty ? filtered : facts.products;
    final buffer = StringBuffer('Tenemos disponibles:\n');
    for (final p in targetList.take(5)) {
      buffer.writeln('• ${p.name} - ${p.priceLabel}');
    }
    if (targetList.length > 5) {
      buffer.writeln('...y ${targetList.length - 5} productos más.');
    }

    return AcceptedBusinessValidation(
      formattedReply: buffer.toString().trim(),
      suggestions: targetList.take(3).map((p) => p.name).toList(),
    );
  }

  BusinessValidationResult _validateAddToCart(AddToCartAction a) {
    final product = _findProduct(a.productId);
    if (product == null) {
      return RejectedBusinessValidation(
        reason: 'Producto no existe para orden: ${a.productId}',
        fallbackReply: 'No pude agregar el producto porque no se encuentra registrado.',
      );
    }

    final availableStock = product.stock ?? 999;
    if (availableStock < a.quantity) {
      return RejectedBusinessValidation(
        reason: 'Stock insuficiente (solicitado: ${a.quantity}, disponible: $availableStock)',
        fallbackReply: 'Solo nos quedan $availableStock unidades de ${product.name}. ¿Deseas llevar esa cantidad?',
      );
    }

    final total = product.price * a.quantity;
    final reply = 'Agregado al pedido: ${a.quantity}x ${product.name} (Total: \$$total). '
        '¿Deseas proceder con la compra o agregar algo más?';

    return AcceptedBusinessValidation(
      formattedReply: reply,
      verifiedProduct: product,
      suggestions: ['Confirmar pedido', 'Ver métodos de pago', 'Seguir viendo'],
    );
  }

  BusinessValidationResult _validatePaymentClaim(PaymentClaimAction a) {
    return EscalatedBusinessValidation(
      reason: 'Comprobante de pago informado por cliente (Monto: ${a.claimedAmount ?? 0}, Ref: ${a.referenceCode ?? 'N/A'})',
      noticeToCustomer: 'Gracias por enviar el comprobante. Nuestro equipo verificará la transacción en la cuenta y te confirmará en breve.',
    );
  }

  BusinessValidationResult _validatePolicyQuery(PolicyQueryAction a) {
    final topic = a.policyTopic.toLowerCase();
    String reply = '';

    if (topic.contains('hour') || topic.contains('horario')) {
      reply = facts.hours.isNotEmpty ? 'Nuestro horario es: ${facts.hours}' : '';
    } else if (topic.contains('delivery') || topic.contains('envio')) {
      reply = facts.delivery.isNotEmpty ? 'Información de envíos: ${facts.delivery}' : '';
    } else if (topic.contains('pay') || topic.contains('pago')) {
      reply = facts.payments.isNotEmpty ? 'Aceptamos los siguientes métodos de pago: ${facts.payments}' : '';
    } else if (topic.contains('loc') || topic.contains('ubicacion')) {
      reply = facts.location.isNotEmpty ? 'Nuestra ubicación es: ${facts.location}' : '';
    }

    if (reply.isEmpty) {
      return const RejectedBusinessValidation(
        reason: 'Política no configurada',
        fallbackReply: 'Con gusto te comunicamos con un asesor para brindarte esa información.',
      );
    }

    return AcceptedBusinessValidation(
      formattedReply: reply,
      suggestions: ['Ver productos', 'Horarios', 'Ubicación'],
    );
  }

  BusinessValidationResult _validateEscalation(EscalateToHumanAction a) {
    return EscalatedBusinessValidation(
      reason: a.reason,
      noticeToCustomer: 'Te he transferido con un asesor humano para ayudarte de forma personalizada. En un momento te responderán.',
    );
  }

  BusinessProduct? _findProduct(String query) {
    if (query.isEmpty) return null;
    final clean = query.toLowerCase().trim();
    for (final p in facts.products) {
      final sku = p.sku?.toLowerCase() ?? '';
      if (p.id.toLowerCase() == clean ||
          sku == clean ||
          p.name.toLowerCase() == clean ||
          p.name.toLowerCase().contains(clean)) {
        return p;
      }
    }
    return null;
  }
}
