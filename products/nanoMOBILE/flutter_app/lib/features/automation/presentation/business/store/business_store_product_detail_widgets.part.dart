part of 'business_store_product_detail_sheet.dart';

/// Nombre y precio no compiten en una fila: admiten valores largos sin recortes.
class _ProductDetailHeader extends StatelessWidget {
  const _ProductDetailHeader({required this.product});
  final BusinessProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.category?.trim().isNotEmpty == true ? product.category!.trim() : 'Sin categoría',
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        SelectableText(
          product.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          product.priceLabel,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Una única fuente calcula disponibilidad. El SKU puede ocupar varias líneas.
class _ProductDetailStockRow extends StatelessWidget {
  const _ProductDetailStockRow({required this.product});
  final BusinessProduct product;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BusinessStoreStockStatus(product: product),
      if (product.sku?.trim().isNotEmpty ?? false) ...[
        const SizedBox(height: 10),
        SelectableText(
          'Referencia: ${product.sku!.trim()}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ],
  );
}

/// Muestra la descripción guardada sin añadir promesas comerciales ni relleno.
class _ProductDetailDescription extends StatelessWidget {
  const _ProductDetailDescription({required this.details});
  final String details;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Descripción', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      SelectableText(details.trim(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
    ],
  );
}

/// Las variantes son información del catálogo: no simulan seleccionar ni comprar.
class _ProductDetailVariants extends StatelessWidget {
  const _ProductDetailVariants({required this.variants});
  final List<String> variants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opciones del producto', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: variants
              .map(
                (variant) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(variant, style: theme.textTheme.bodySmall),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
