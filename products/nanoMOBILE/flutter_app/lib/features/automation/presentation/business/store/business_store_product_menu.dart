// business_store_product_menu.dart
//
// QUÉ HACE:
// Menú de opciones compacto y discreto (3 puntos) para cada producto del catálogo.
//
// CÓMO FUNCIONA:
// - Botón de 30×30 dp con icono sutil de elipsis y esquinas redondeadas.
// - Despliega menú flotante: Ver producto, Editar y Compartir.
//
// POR QUÉ:
// Elimina el botón circular invasivo y optimiza la jerarquía visual (< 65 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import '../business_library_action_menu.dart';

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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: 'Opciones de ${product.name}',
      child: CupertinoButton(
        onPressed: () => _show(context),
        minimumSize: const Size.square(30),
        padding: EdgeInsets.zero,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            CupertinoIcons.ellipsis,
            size: 16,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

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
