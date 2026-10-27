import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import '../business_library_action_menu.dart';

/// Un único menú accesible conserva las acciones existentes sin comprimir
/// editar y compartir en dos iconos pequeños dentro de la tarjeta.
class BusinessStoreProductMenu extends StatelessWidget {
  const BusinessStoreProductMenu({
    super.key,
    required this.product,
    required this.onOpen,
    required this.onEdit,
    required this.onShare,
  });
  final BusinessProduct product;
  final ValueChanged<BusinessProduct> onOpen, onEdit, onShare;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Acciones del producto',
    onPressed: () => _show(context),
    icon: const Icon(Icons.more_horiz_rounded, size: 22),
    style: IconButton.styleFrom(
      minimumSize: const Size.square(44),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
    ),
  );

  Future<void> _show(BuildContext context) async {
    final action = await showBusinessLibraryMenu(
      context,
      title: product.name,
      options: const [
        BusinessLibraryOption('open', 'Ver producto'),
        BusinessLibraryOption('edit', 'Editar'),
        BusinessLibraryOption('share', 'Compartir'),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'open':
        onOpen(product);
      case 'edit':
        onEdit(product);
      case 'share':
        onShare(product);
    }
  }
}
