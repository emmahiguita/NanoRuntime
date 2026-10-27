// business_store_product_detail_sheet.dart
//
// QUÉ HACE:
// Ventana flotante estilo iOS Liquid Glass con la ficha técnica completa del producto.
// Muestra foto/video en gran formato, variantes, SKU, disponibilidad y acciones de venta.
//
// CÓMO FUNCIONA:
// - Abre un panel flotante en showNanoGlassWindow y renderiza multimedia HD.
// - Presenta chips de variantes y desglose de precio y stock.
//
// POR QUÉ:
// Respeta el Single Responsibility Principle (< 200 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';

part 'business_store_product_detail_actions.part.dart';
part 'business_store_product_detail_widgets.part.dart';

class BusinessStoreProductDetailSheet extends StatelessWidget {
  final BusinessProduct product;
  final ValueChanged<BusinessProduct> onEdit, onShare;

  const BusinessStoreProductDetailSheet({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onShare,
  });

  static Future<void> show(
    BuildContext context, {
    required BusinessProduct product,
    required ValueChanged<BusinessProduct> onEdit,
    required ValueChanged<BusinessProduct> onShare,
  }) => showNanoGlassWindow(
    context: context,
    useRootNavigator: true,
    builder: (_) => BusinessStoreProductDetailSheet(
      product: product,
      onEdit: onEdit,
      onShare: onShare,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BusinessStoreMediaView(
            mediaPath: product.imagePath,
            height: 150,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 12),
          _ProductDetailHeader(product: product, onSurface: onSurface),
          const SizedBox(height: 10),
          _ProductDetailStockRow(product: product, onSurface: onSurface),
          if (product.details.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProductDetailDescription(
              details: product.details,
              onSurface: onSurface,
            ),
          ],
          if (product.variants.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProductDetailVariants(
              variants: product.variants,
              onSurface: onSurface,
            ),
          ],
          const SizedBox(height: 16),
          _ProductDetailActions(
            onSurface: onSurface,
            onEdit: () {
              Navigator.pop(context);
              onEdit(product);
            },
            onShare: () {
              Navigator.pop(context);
              onShare(product);
            },
          ),
        ],
      ),
    );
  }
}
