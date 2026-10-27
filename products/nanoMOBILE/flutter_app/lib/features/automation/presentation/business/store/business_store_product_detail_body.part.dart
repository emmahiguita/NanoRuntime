part of 'business_store_product_detail_sheet.dart';

/// Fotografía completa y datos con jerarquía editorial. En ventanas anchas usa
/// dos columnas; en móvil apila todo y mantiene el desplazamiento natural.
class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({required this.product});
  final BusinessProduct product;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = BusinessStoreMediaView(
        mediaPath: product.imagePath,
        height: (MediaQuery.sizeOf(context).height * .3).clamp(160.0, 280.0),
        fit: BoxFit.contain,
        borderRadius: BorderRadius.circular(16),
      );
      final information = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProductDetailHeader(product: product),
          const SizedBox(height: 12),
          _ProductDetailStockRow(product: product),
          if (product.details.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            _ProductDetailDescription(details: product.details),
          ],
          if (product.variants.isNotEmpty) ...[
            const SizedBox(height: 24),
            _ProductDetailVariants(variants: product.variants),
          ],
        ],
      );
      if (constraints.maxWidth >= 540 && MediaQuery.textScalerOf(context).scale(14) < 20) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: media),
            const SizedBox(width: 24),
            Expanded(child: information),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [media, const SizedBox(height: 20), information],
      );
    },
  );
}
