import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/glass_surface.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';
import 'business_store_stock_status.dart';

part 'business_store_product_detail_actions.part.dart';
part 'business_store_product_detail_widgets.part.dart';
part 'business_store_product_detail_body.part.dart';

/// Ficha flotante con un solo cristal y cierre. El contenido puede desplazarse
/// mientras editar y compartir siguen visibles, sin alterar el producto guardado.
class BusinessStoreProductDetailSheet extends StatelessWidget {
  const BusinessStoreProductDetailSheet({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onShare,
  });
  final BusinessProduct product;
  final ValueChanged<BusinessProduct> onEdit, onShare;

  static Future<void> show(
    BuildContext context, {
    required BusinessProduct product,
    required ValueChanged<BusinessProduct> onEdit,
    required ValueChanged<BusinessProduct> onShare,
  }) => showNanoGlassWindow(
    context: context,
    useRootNavigator: true,
    chrome: NanoWindowChrome.contentOwned,
    builder: (_) => BusinessStoreProductDetailSheet(product: product, onEdit: onEdit, onShare: onShare),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .94,
    child: GlassSurface(
      padding: EdgeInsets.zero,
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
            child: Row(
              children: [
                Expanded(child: Text('Detalle del producto', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Cerrar producto',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _ProductDetailBody(product: product),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _ProductDetailActions(
              onEdit: () {
                Navigator.pop(context);
                onEdit(product);
              },
              onShare: () {
                Navigator.pop(context);
                onShare(product);
              },
            ),
          ),
        ],
      ),
    ),
  );
}
