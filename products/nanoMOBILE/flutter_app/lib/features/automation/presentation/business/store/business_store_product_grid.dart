import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_product_card.dart';

/// Calcula columnas con el ancho real y la escala de texto del teléfono.
/// Reserva dos líneas para nombre y disponibilidad, evitando alturas por intuición.
class BusinessStoreProductGrid extends StatelessWidget {
  const BusinessStoreProductGrid({
    super.key,
    required this.products,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
  });
  final List<BusinessProduct> products;
  final ValueChanged<BusinessProduct> onTap, onEdit, onShare;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context);
      final width = math.max(1.0, constraints.crossAxisExtent - 32);
      final minimum = 148 * math.max(1.0, scale.scale(14) / 14);
      final columns = ((width + 12) / (minimum + 12))
          .floor()
          .clamp(1, 3)
          .clamp(1, math.max(1, products.length));
      final cardWidth = (width - 12 * (columns - 1)) / columns;
      final mediaHeight = (cardWidth * .75).clamp(110.0, 240.0);
      final textHeight =
          scale.scale(11) * 1.25 +
          scale.scale(14) * 1.3 * 2 +
          scale.scale(17) * 1.2 +
          scale.scale(11) * 1.25 * 2;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns.toInt(),
            mainAxisExtent: mediaHeight + textHeight + 64,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => BusinessStoreProductCard(
              key: ValueKey(products[index].id),
              product: products[index],
              onTap: onTap,
              onEdit: onEdit,
              onShare: onShare,
            ),
            childCount: products.length,
          ),
        ),
      );
    },
  );
}
