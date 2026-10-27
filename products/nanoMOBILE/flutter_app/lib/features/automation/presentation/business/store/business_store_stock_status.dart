import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';

/// Presenta solo disponibilidad verificable del producto guardado. Un stock
/// desconocido no se convierte en «Disponible» y una unidad usa singular.
class BusinessStoreStockStatus extends StatelessWidget {
  const BusinessStoreStockStatus({super.key, required this.product, this.compact = false});
  final BusinessProduct product;
  final bool compact;

  static String label(BusinessProduct product) {
    if (!product.isAvailable) return 'Pausado';
    final stock = product.stock;
    if (stock == null) return 'Consultar disponibilidad';
    if (stock <= 0) return 'Agotado';
    return stock == 1 ? '1 unidad disponible' : '$stock unidades disponibles';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final exhausted = product.isAvailable && product.stock != null && product.stock! <= 0;
    return Semantics(
      label: label(product),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: exhausted
              ? colors.errorContainer.withValues(alpha: .5)
              : colors.surfaceContainerHighest.withValues(alpha: .45),
        ),
        child: Text(
          label(product),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: exhausted ? colors.onErrorContainer : colors.onSurfaceVariant,
            fontSize: compact ? 11 : 12,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
