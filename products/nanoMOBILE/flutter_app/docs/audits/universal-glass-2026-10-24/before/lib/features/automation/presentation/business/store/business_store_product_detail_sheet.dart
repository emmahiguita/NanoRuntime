// business_store_product_detail_sheet.dart
//
// QUÉ HACE:
// Modal bottom sheet estilo iOS Liquid Glass con la ficha técnica completa del producto.
// Muestra foto/video en gran formato, variantes, SKU, disponibilidad y acciones de venta.
//
// CÓMO FUNCIONA:
// - Abre un panel flotante con BackdropFilter blur y renderizado multimedia HD.
// - Presenta chips de variantes y desglose de precio y stock.
//
// POR QUÉ:
// Respeta el Single Responsibility Principle (< 150 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../engine/business/business_product.dart';
import 'business_store_media_view.dart';

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
  }) => showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BusinessStoreProductDetailSheet(product: product, onEdit: onEdit, onShare: onShare),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF20E1A27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: Color(0x3364B5F6))),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF475569), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            BusinessStoreMediaView(
              mediaPath: product.imagePath,
              height: 150,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.category != null && product.category!.trim().isNotEmpty)
                        Text(
                          product.category!.trim().toUpperCase(),
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                        ),
                      Text(
                        product.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Text(
                  product.priceLabel,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: product.isAvailable ? const Color(0x2610B981) : const Color(0x26EF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.isAvailable ? 'Disponible' : 'Pausado',
                    style: TextStyle(
                      color: product.isAvailable ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (product.stock != null) ...[
                  const SizedBox(width: 8),
                  Text('Stock: ${product.stock} unidades', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
                if (product.sku != null && product.sku!.trim().isNotEmpty) ...[
                  const Spacer(),
                  Text('SKU: ${product.sku!.trim()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ],
            ),
            if (product.details.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x331E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x265D91B8)),
                ),
                child: Text(
                  product.details.trim(),
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, height: 1.35),
                ),
              ),
            ],
            if (product.variants.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: product.variants
                    .map((v) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x331E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0x3364B5F6)),
                          ),
                          child: Text(v, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit(product);
                    },
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    color: const Color(0x331E293B),
                    borderRadius: BorderRadius.circular(12),
                    child: const Text('Editar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: CupertinoButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onShare(product);
                    },
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    color: const Color(0xFF087BFF),
                    borderRadius: BorderRadius.circular(12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.share, size: 15, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Enviar / Compartir', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
