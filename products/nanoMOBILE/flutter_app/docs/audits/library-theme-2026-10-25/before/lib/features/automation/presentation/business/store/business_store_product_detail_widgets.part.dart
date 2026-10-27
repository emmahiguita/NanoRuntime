part of 'business_store_product_detail_sheet.dart';

class _ProductDetailHeader extends StatelessWidget {
  final BusinessProduct product;
  final Color onSurface;

  const _ProductDetailHeader({required this.product, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.category != null &&
                  product.category!.trim().isNotEmpty)
                Text(
                  product.category!.trim().toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              Text(
                product.name,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Text(
          product.priceLabel,
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProductDetailStockRow extends StatelessWidget {
  final BusinessProduct product;
  final Color onSurface;

  const _ProductDetailStockRow({
    required this.product,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: product.isAvailable
                ? const Color(0x2610B981)
                : const Color(0x26EF4444),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            product.isAvailable ? 'Disponible' : 'Pausado',
            style: TextStyle(
              color: product.isAvailable
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF87171),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (product.stock != null) ...[
          const SizedBox(width: 8),
          Text(
            'Stock: ${product.stock} unidades',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.65),
              fontSize: 11,
            ),
          ),
        ],
        if (product.sku != null && product.sku!.trim().isNotEmpty) ...[
          const Spacer(),
          Text(
            'SKU: ${product.sku!.trim()}',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductDetailDescription extends StatelessWidget {
  final String details;
  final Color onSurface;

  const _ProductDetailDescription({
    required this.details,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x331E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x265D91B8)),
      ),
      child: Text(
        details.trim(),
        style: TextStyle(
          color: onSurface.withValues(alpha: 0.88),
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ProductDetailVariants extends StatelessWidget {
  final List<String> variants;
  final Color onSurface;

  const _ProductDetailVariants({
    required this.variants,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: variants
          .map(
            (v) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x331E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x3364B5F6)),
              ),
              child: Text(
                v,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
