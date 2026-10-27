// pdf_product_review_dialog.dart
//
// QUÉ HACE:
// Ventana flotante de revisión y aprobación de productos detectados en documentos PDF.
//
// CÓMO FUNCIONA:
// - Muestra la lista de `PdfProductProposal` extraídas del PDF sobre GlassSurface.
// - Permite al dueño marcar/desmarcar cuáles autoriza para la Tienda oficial.
// - Aplica los cambios aprobados en `BusinessFactsStore` únicamente con confirmación explícita.
//
// POR QUÉ:
// Implementa el principio de demarcación estricta entre RAG documental y hechos oficiales.

library;

import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import '../../../engine/business/business_facts.dart';
import '../../../engine/business/proposals/pdf_product_proposal.dart';
import 'pdf_product_review_item_tile.dart';

class PdfProductReviewDialog extends StatefulWidget {
  final String documentTitle;
  final List<PdfProductProposal> proposals;
  final BusinessFacts facts;
  final Future<void> Function(List<BusinessProduct> approvedProducts) onCommit;

  const PdfProductReviewDialog({
    super.key,
    required this.documentTitle,
    required this.proposals,
    required this.facts,
    required this.onCommit,
  });

  static Future<void> show(
    BuildContext context, {
    required String documentTitle,
    required List<PdfProductProposal> proposals,
    required BusinessFacts facts,
    required Future<void> Function(List<BusinessProduct> approvedProducts)
    onCommit,
  }) {
    return showNanoGlassWindow<void>(
      context: context,
      builder: (_) => PdfProductReviewDialog(
        documentTitle: documentTitle,
        proposals: proposals,
        facts: facts,
        onCommit: onCommit,
      ),
    );
  }

  @override
  State<PdfProductReviewDialog> createState() => _PdfProductReviewDialogState();
}

class _PdfProductReviewDialogState extends State<PdfProductReviewDialog> {
  late List<PdfProductProposal> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.proposals);
  }

  int get _selectedCount => _items.where((i) => i.isSelected).length;

  Future<void> _handleApprove() async {
    final approved = _items
        .where((i) => i.isSelected)
        .map((i) => i.toBusinessProduct())
        .toList();

    if (approved.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    await widget.onCommit(approved);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${approved.length} productos agregados a la Tienda oficial.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revisión de Productos en Documento',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Documento: ${widget.documentTitle} · Selecciona qué productos autorizas incorporar al catálogo.',
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _items[index];
                return PdfProductReviewItemTile(
                  item: item,
                  onToggle: (val) => setState(() {
                    _items[index] = item.copyWith(isSelected: val);
                  }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedCount == 0 || _isSaving
                        ? null
                        : _handleApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Aprobar e Importar ($_selectedCount)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
