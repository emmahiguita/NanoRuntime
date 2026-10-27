// Valida una propuesta de carrito; la aprobación se controla en el runtime.
part of 'business_response_validator.dart';

extension _BusinessCartValidation on BusinessResponseValidator {
  BusinessValidationResult _validateAddToCart(AddToCartAction a) {
    final product = _findProduct(a.productId);
    if (product == null) {
      return RejectedBusinessValidation(
        reason: 'Producto no existe para orden: ${a.productId}',
        fallbackReply:
            'No pude agregar el producto porque no se encuentra registrado.',
      );
    }

    // Rechaza cantidades inválidas y stock desconocido antes de proponer el carrito.
    final availableStock = product.stock;
    if (a.quantity <= 0 || availableStock == null) {
      return const RejectedBusinessValidation(
        reason: 'Cantidad inválida o inventario sin registrar',
        fallbackReply:
            'Necesitamos confirmar cantidad y disponibilidad antes de añadir el producto.',
      );
    }
    if (availableStock < a.quantity) {
      return RejectedBusinessValidation(
        reason:
            'Stock insuficiente (solicitado: ${a.quantity}, disponible: $availableStock)',
        fallbackReply:
            'Solo nos quedan $availableStock unidades de ${product.name}. ¿Deseas llevar esa cantidad?',
      );
    }

    final total = product.price * a.quantity;
    final reply =
        'Propuesta pendiente de confirmación: ${a.quantity}x ${product.name} (Total: \$$total). '
        'El carrito todavía no ha sido modificado.';

    return AcceptedBusinessValidation(
      formattedReply: reply,
      verifiedProduct: product,
      suggestions: ['Confirmar pedido', 'Ver métodos de pago', 'Seguir viendo'],
    );
  }
}
