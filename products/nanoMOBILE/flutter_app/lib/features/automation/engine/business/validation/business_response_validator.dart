// Valida datos comerciales contra el catálogo guardado, sin inventar existencias.
library;

import '../actions/commercial_structured_action.dart';
import '../business_facts.dart';
import 'business_validation_result.dart';

part 'business_cart_validation.dart';

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
        fallbackReply:
            'No encontré ese producto en nuestro catálogo actual. '
            '¿Deseas que te comparta los productos disponibles?',
      );
    }

    final reply =
        'El ${product.name} tiene un precio de ${product.priceLabel}.';
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
        fallbackReply:
            'No localicé ese producto en inventario. ¿Me confirmas el nombre exacto?',
      );
    }

    // Inventario sin registrar no equivale a agotado ni a existencias ilimitadas.
    final stock = product.stock;
    if (stock == null) {
      return const RejectedBusinessValidation(
        reason: 'Inventario no registrado',
        fallbackReply: 'La disponibilidad de ese producto está por confirmar.',
      );
    }
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
        fallbackReply: 'No hay productos registrados en el catálogo actual.',
      );
    }

    final targetCat = a.category?.toLowerCase();
    final available = facts.products.where((p) => p.isAvailable).toList();
    final filtered = targetCat != null && targetCat.isNotEmpty
        ? available
              .where((p) => (p.category ?? '').toLowerCase() == targetCat)
              .toList()
        : available;

    final targetList = filtered;
    if (targetList.isEmpty) {
      return const RejectedBusinessValidation(
        reason: 'Sin productos activos en la categoría',
        fallbackReply:
            'No hay productos activos registrados para esa consulta.',
      );
    }
    final buffer = StringBuffer('Catálogo registrado:\n');
    for (final p in targetList.take(5)) {
      final availability = p.stock == null
          ? 'disponibilidad por confirmar'
          : p.stock! > 0
          ? '${p.stock} unidades'
          : 'agotado';
      buffer.writeln('• ${p.name} - ${p.priceLabel} ($availability)');
    }
    if (targetList.length > 5) {
      buffer.writeln('...y ${targetList.length - 5} productos más.');
    }

    return AcceptedBusinessValidation(
      formattedReply: buffer.toString().trim(),
      suggestions: targetList.take(3).map((p) => p.name).toList(),
    );
  }

  BusinessValidationResult _validatePaymentClaim(PaymentClaimAction a) {
    return EscalatedBusinessValidation(
      reason:
          'Comprobante de pago informado por cliente (Monto: ${a.claimedAmount ?? 0}, Ref: ${a.referenceCode ?? 'N/A'})',
      noticeToCustomer:
          'El comprobante requiere revisión humana; el pago aún no está confirmado.',
    );
  }

  BusinessValidationResult _validatePolicyQuery(PolicyQueryAction a) {
    final topic = a.policyTopic.toLowerCase();
    String reply = '';

    if (topic.contains('hour') || topic.contains('horario')) {
      reply = facts.hours.isNotEmpty
          ? 'Nuestro horario es: ${facts.hours}'
          : '';
    } else if (topic.contains('delivery') || topic.contains('envio')) {
      reply = facts.delivery.isNotEmpty
          ? 'Información de envíos: ${facts.delivery}'
          : '';
    } else if (topic.contains('pay') || topic.contains('pago')) {
      reply = facts.payments.isNotEmpty
          ? 'Aceptamos los siguientes métodos de pago: ${facts.payments}'
          : '';
    } else if (topic.contains('loc') || topic.contains('ubicacion')) {
      reply = facts.location.isNotEmpty
          ? 'Nuestra ubicación es: ${facts.location}'
          : '';
    }

    if (reply.isEmpty) {
      return const RejectedBusinessValidation(
        reason: 'Política no configurada',
        fallbackReply:
            'Esa información no está registrada y requiere revisión humana.',
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
      noticeToCustomer:
          'Tu consulta requiere atención humana. La transferencia a un asesor no está confirmada.',
    );
  }

  BusinessProduct? _findProduct(String query) {
    if (query.isEmpty) return null;
    final clean = query.toLowerCase().trim();
    for (final p in facts.products) {
      if (!p.isAvailable) continue;
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
