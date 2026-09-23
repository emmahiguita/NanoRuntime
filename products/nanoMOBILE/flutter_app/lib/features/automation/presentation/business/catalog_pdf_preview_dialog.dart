import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/business/business_facts.dart';
import '../../engine/business/catalog_pdf_generator.dart';
import '../../engine/platform/whatsapp_media_share.dart';
import '../automation_visual_theme.dart';
import '../widgets/dialogs/dialog_container_shell.dart';

// catalog_pdf_preview_dialog.dart
//
// QUÉ HACE:
// Modal interactivo para previsualizar, exportar y enviar el catálogo comercial
// generado en PDF directamente a contactos de WhatsApp.
//
// CÓMO FUNCIONA:
// - Genera el PDF en memoria mediante CatalogPdfGenerator.
// - Permite enviar el archivo a través de WhatsAppMediaShare o el menú del sistema.
// - Utiliza DialogContainerShell para evitar cualquier error de Overlay y desbordamiento.
//
// POR QUÉ:
// Proporciona a los negocios una herramienta ágil para cotizaciones y catálogos en WhatsApp (< 200 líneas).

class CatalogPdfPreviewDialog extends StatefulWidget {
  final BusinessFacts facts;
  const CatalogPdfPreviewDialog({super.key, required this.facts});

  static Future<void> show(BuildContext context, BusinessFacts facts) {
    return showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => CatalogPdfPreviewDialog(facts: facts),
    );
  }

  @override
  State<CatalogPdfPreviewDialog> createState() => _CatalogPdfPreviewDialogState();
}

class _CatalogPdfPreviewDialogState extends State<CatalogPdfPreviewDialog> {
  bool _generating = false;

  Future<void> _shareToWhatsApp() async {
    setState(() => _generating = true);
    try {
      final file = await CatalogPdfGenerator.generateAndSaveFile(facts: widget.facts);
      const share = WhatsAppMediaShare();
      final launched = await share.shareFile(
        path: file.path,
        contact: '',
        caption: 'Adjunto nuestro catálogo comercial en formato PDF.',
      );

      if (!launched && mounted) {
        // Fallback a menú de compartir estándar
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf', name: 'catalogo.pdf')],
            text: 'Catálogo oficial de productos',
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _previewAndPrint() async {
    setState(() => _generating = true);
    try {
      final bytes = await CatalogPdfGenerator.generatePdfBytes(facts: widget.facts);
      await Printing.sharePdf(bytes: bytes, filename: 'catalogo_comercial.pdf');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final count = widget.facts.products.length;

    return DialogContainerShell(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: visual.accentSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.picture_as_pdf_rounded, color: visual.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catálogo en PDF', style: TextStyle(color: visual.text, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$count productos listos para WhatsApp', style: TextStyle(color: visual.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: visual.accentSoft.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Características del Catálogo:', style: TextStyle(color: visual.text, fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('• Formato A4 profesional con precios en moneda local.', style: TextStyle(color: visual.textMuted, fontSize: 11)),
                  Text('• Código QR interactivo para retornar al chat de compra.', style: TextStyle(color: visual.textMuted, fontSize: 11)),
                  Text('• Compatible con el visor nativo de documentos de WhatsApp.', style: TextStyle(color: visual.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _generating ? null : _shareToWhatsApp,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar por WhatsApp'),
              style: FilledButton.styleFrom(backgroundColor: visual.accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _generating ? null : _previewAndPrint,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Previsualizar o Imprimir'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
