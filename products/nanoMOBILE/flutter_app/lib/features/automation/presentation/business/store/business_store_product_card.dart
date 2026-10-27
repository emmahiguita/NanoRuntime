import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';
import 'business_store_product_menu.dart';
import 'business_store_stock_status.dart';

/// Tarjeta del catálogo: fotografía, categoría, nombre, precio y disponibilidad.
/// El menú conserva las acciones reales; toda la tarjeta abre la misma ficha.
class BusinessStoreProductCard extends StatelessWidget {
  const BusinessStoreProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
  });
  final BusinessProduct product;
  final ValueChanged<BusinessProduct> onTap, onEdit, onShare;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final category = product.category?.trim() ?? '';
    return Material(
      color: colors.surface.withValues(alpha: .62),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: (constraints.maxWidth * .75).clamp(110.0, 240.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BusinessStoreMediaView(mediaPath: product.imagePath, fit: BoxFit.contain),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: BusinessStoreProductMenu(
                        product: product,
                        onOpen: onTap,
                        onEdit: onEdit,
                        onShare: onShare,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.isEmpty ? 'Sin categoría' : category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, height: 1.25, color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 8),
                    BusinessStoreStockStatus(product: product, compact: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
