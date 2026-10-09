// business_store_product_list_row.dart
//
// QUÉ HACE:
// Fila horizontal de producto para la vista en lista de la tienda comercial.
// Ofrece una lectura compacta y rápida de stock, precio, SKU y presentación multimedia.
//
// CÓMO FUNCIONA:
// - Despliega miniatura de foto/video mediante BusinessStoreMediaView.
// - Muestra nombre, categoría, precio, stock y detalles en una sola línea estructurada.
//
// POR QUÉ:
// Aplica SOLID modularizando la vista de lista en un componente limpio de < 150 líneas.

import 'package:flutter/cupertino.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';

class BusinessStoreProductListRow extends StatelessWidget {
  final BusinessProduct product;
  final ValueChanged<BusinessProduct> onTap;
  final ValueChanged<BusinessProduct> onEdit;
  final ValueChanged<BusinessProduct> onShare;

  const BusinessStoreProductListRow({
    super.key,
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CupertinoButton(
        onPressed: () => onTap(product),
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xB3152232),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: product.isAvailable
                  ? const Color(0x265D91B8)
                  : const Color(0x33EF4444),
            ),
          ),
          child: Row(
            children: [
              BusinessStoreMediaView(
                mediaPath: product.imagePath,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(10),
                showVideoBadge: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: product.isAvailable
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF94A3B8),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _buildStatusIndicator(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          product.priceLabel,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.category != null && product.category!.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${product.category!.trim()}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (product.details.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.details.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (!product.isAvailable) {
      return const Text('⛔ Pausado', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700));
    }
    if (product.stock != null) {
      return Text(
        product.stock! <= 0 ? 'Agotado' : '${product.stock} disp.',
        style: TextStyle(
          color: product.stock! <= 0 ? const Color(0xFFF97316) : const Color(0xFF10B981),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActions() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: () => onEdit(product),
            child: const Icon(CupertinoIcons.pencil, size: 16, color: Color(0xFF94A3B8)),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: () => onShare(product),
            child: const Icon(CupertinoIcons.share, size: 16, color: Color(0xFF64B5F6)),
          ),
        ],
      );
}
