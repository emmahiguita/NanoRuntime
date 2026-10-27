import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';
import 'business_store_product_menu.dart';
import 'business_store_stock_status.dart';

/// Fila de altura natural: el texto crece sin competir con el precio o el menú.
/// Comparte datos y acciones con la cuadrícula; no mantiene otra copia del stock.
class BusinessStoreProductListRow extends StatelessWidget {
  const BusinessStoreProductListRow({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: colors.surface.withValues(alpha: .62),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageSize = constraints.maxWidth < 300 ? 60.0 : 80.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BusinessStoreMediaView(
                      mediaPath: product.imagePath,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(12),
                      showVideoBadge: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          if (product.category?.trim().isNotEmpty ?? false) ...[
                            const SizedBox(height: 4),
                            Text(
                              product.category!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            product.priceLabel,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          BusinessStoreStockStatus(product: product, compact: true),
                        ],
                      ),
                    ),
                    BusinessStoreProductMenu(
                      product: product,
                      onOpen: onTap,
                      onEdit: onEdit,
                      onShare: onShare,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
