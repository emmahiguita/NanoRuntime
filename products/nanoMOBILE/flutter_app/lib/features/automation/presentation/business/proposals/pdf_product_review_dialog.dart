// pdf_product_review_dialog.dart
//
// QUÉ HACE:
// Diálogo modal de revisión y aprobación de productos detectados en documentos PDF.
//
// CÓMO FUNCIONA:
// - Muestra la lista de `PdfProductProposal` extraídas del PDF.
// - Permite al dueño marcar/desmarcar cuáles autoriza para la Tienda oficial.
// - Aplica los cambios aprobados en `BusinessFactsStore` únicamente con confirmación explícita.
//
// POR QUÉ:
// Implementa el principio de demarcación estricta entre RAG documental y hechos oficiales.

library;

import 'dart:ui';
import 'package:flutter/material.dart';
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
    required Future<void> Function(List<BusinessProduct> approvedProducts) onCommit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          content: Text('${approved.length} productos agregados a la Tienda oficial.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revisión de Productos en Documento',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Documento: ${widget.documentTitle} · Selecciona qué productos autorizas incorporar al catálogo.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedCount == 0 || _isSaving ? null : _handleApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Aprobar e Importar ($_selectedCount)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
