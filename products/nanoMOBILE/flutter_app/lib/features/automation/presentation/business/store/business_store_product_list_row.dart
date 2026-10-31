// business_store_product_list_row.dart
//
// QUÉ HACE:
// Fila compacta y profesional para productos del catálogo de Nano.
//
// CÓMO FUNCIONA:
// - Imagen protagonista de 72×72 dp con esquinas de 12 dp y proporción cuidada.
// - Jerarquía limpia: Nombre, Categoría/SKU, Precio destacado y Disponibilidad.
// - Menú de 3 puntos discreto y tarjeta con superficie nítida y contraste definido.
//
// POR QUÉ:
// Satisface fielmente la especificación de diseño profesional Apple/Material 3 (< 120 líneas).

import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';
import 'business_store_product_menu.dart';
import 'business_store_stock_status.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final category = product.category?.trim() ?? '';
    final sku = product.sku?.trim() ?? '';
    final secondaryInfo = [
      if (category.isNotEmpty) category,
      if (sku.isNotEmpty) 'SKU: $sku',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 0.85),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BusinessStoreMediaView(
                  mediaPath: product.imagePath,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  showVideoBadge: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (secondaryInfo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          secondaryInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            product.priceLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: BusinessStoreStockStatus(
                              product: product,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                BusinessStoreProductMenu(
                  product: product,
                  onOpen: onTap,
                  onEdit: onEdit,
                  onShare: onShare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
