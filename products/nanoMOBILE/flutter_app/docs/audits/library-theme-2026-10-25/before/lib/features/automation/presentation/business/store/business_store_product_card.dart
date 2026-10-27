// business_store_product_card.dart
//
// QUÉ HACE:
// Tarjeta de producto estilo iOS Liquid Glass de alta fidelidad para la tienda.
// Presenta foto/video HD, categoría, stock, precio y accesos rápidos sin riesgo de desbordamiento.
//
// CÓMO FUNCIONA:
// - Renderiza medios con BusinessStoreMediaView y viñeta de iluminación suave.
// - Distribuye jerárquicamente título, precio destacado y ficha descriptiva.
//
// POR QUÉ:
// Aplica SOLID modularizando la tarjeta en un componente autocontenido de < 165 líneas.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';

class BusinessStoreProductCard extends StatelessWidget {
  final BusinessProduct product;
  final ValueChanged<BusinessProduct> onTap, onEdit, onShare;

  const BusinessStoreProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: () => onTap(product),
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xB3152232),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: product.isAvailable
                ? const Color(0x335D91B8)
                : const Color(0x33EF4444),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVisualHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: product.isAvailable ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.priceLabel,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.details.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.details.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, height: 1.25),
                          ),
                        ],
                      ],
                    ),
                    _buildActionBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualHeader() => SizedBox(
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BusinessStoreMediaView(mediaPath: product.imagePath),
            if (product.category != null && product.category!.trim().isNotEmpty)
              Positioned(
                top: 5,
                left: 5,
                child: _badge(product.category!.trim(), const Color(0xCC0F172A), const Color(0xFF93C5FD)),
              ),
            Positioned(top: 5, right: 5, child: _buildStockBadge()),
          ],
        ),
      );

  Widget _buildStockBadge() {
    if (!product.isAvailable) {
      return _badge('Pausado', const Color(0xDDEF4444), Colors.white);
    }
    if (product.stock != null) {
      return product.stock! <= 0
          ? _badge('Agotado', const Color(0xDDF97316), Colors.white)
          : _badge('Stock: ${product.stock}', const Color(0xDD10B981), Colors.white);
    }
    return _badge('Activo', const Color(0xCC0284C7), Colors.white);
  }

  Widget _badge(String text, Color bg, Color textCol) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: TextStyle(color: textCol, fontSize: 9, fontWeight: FontWeight.w700)),
      );

  Widget _buildActionBar() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(24, 24),
            onPressed: () => onEdit(product),
            child: const Icon(CupertinoIcons.pencil, size: 14, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(24, 24),
            onPressed: () => onShare(product),
            child: const Icon(CupertinoIcons.share, size: 14, color: Color(0xFF64B5F6)),
          ),
        ],
      );
}
