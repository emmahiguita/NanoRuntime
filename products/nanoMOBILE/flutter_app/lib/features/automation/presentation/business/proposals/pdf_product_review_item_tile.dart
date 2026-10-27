// pdf_product_review_item_tile.dart
//
// QUÉ HACE:
// Tarjeta individual para mostrar y seleccionar una propuesta de producto extraída de PDF.
//
// CÓMO FUNCIONA:
// - Checkbox de selección, nombre sugerido, detalle de procedencia y precio formateado.
//
// POR QUÉ:
// Mantiene los componentes desacoplados y con menos de 100 líneas (SOLID).

library;

import 'package:flutter/material.dart';
import '../../../engine/business/proposals/pdf_product_proposal.dart';

class PdfProductReviewItemTile extends StatelessWidget {
  final PdfProductProposal item;
  final ValueChanged<bool> onToggle;

  const PdfProductReviewItemTile({
    super.key,
    required this.item,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isSelected ? const Color(0xFF38BDF8) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (val) => onToggle(val ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.suggestedName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  item.suggestedDetails,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '\$${item.suggestedPrice}',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
