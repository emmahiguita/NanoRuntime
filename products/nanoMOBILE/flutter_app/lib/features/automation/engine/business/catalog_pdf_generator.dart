import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'business_facts.dart';

// catalog_pdf_generator.dart
//
// QUÉ HACE:
// Genera un catálogo comercial en formato PDF profesional a partir de los productos
// y datos comerciales de BusinessFacts, optimizado para visualización en WhatsApp.
//
// CÓMO FUNCIONA:
// - Construye un documento vectorial con encabezado corporativo, grilla de productos y precios.
// - Inserta un código QR interactivo con enlace directo a WhatsApp (wa.me) para retorno de compra.
// - Guarda el archivo en almacenamiento temporal y retorna su ruta o bytes.
//
// POR QUÉ:
// Permite que el bot y el comerciante envíen un catálogo descargable que WhatsApp
// previsualiza y abre de forma nativa sin salir de la app (< 200 líneas).

class CatalogPdfGenerator {
  /// Genera los bytes del catálogo en PDF.
  static Future<Uint8List> generatePdfBytes({
    required BusinessFacts facts,
    String businessName = 'Catálogo Oficial de Productos',
    String? whatsappNumber,
  }) async {
    final pdf = pw.Document();

    final cleanPhone = (whatsappNumber ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final waLink = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=Hola,%20vi%20su%20catálogo%20y%20deseo%20comprar'
        : 'https://wa.me/';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(businessName, facts),
          pw.SizedBox(height: 16),
          _buildProductTable(facts.products),
          pw.SizedBox(height: 20),
          _buildFooter(facts, waLink),
        ],
      ),
    );

    return pdf.save();
  }

  /// Guarda el catálogo generado en el directorio temporal y retorna la ruta del archivo.
  static Future<File> generateAndSaveFile({
    required BusinessFacts facts,
    String businessName = 'Catálogo Oficial de Productos',
    String? whatsappNumber,
  }) async {
    final bytes = await generatePdfBytes(
      facts: facts,
      businessName: businessName,
      whatsappNumber: whatsappNumber,
    );
    final tempDir = await getTemporaryDirectory();
    final sanitized = businessName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final file = File('${tempDir.path}/${sanitized}_catalogo.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static pw.Widget _buildHeader(String title, BusinessFacts facts) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
              if (facts.location.isNotEmpty)
                pw.Text('Ubicación: ${facts.location}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (facts.hours.isNotEmpty)
                pw.Text('Horario: ${facts.hours}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          pw.Text('Nano Business', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
        ],
      ),
    );
  }

  static pw.Widget _buildProductTable(List<BusinessProduct> products) {
    if (products.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 30),
        child: pw.Center(child: pw.Text('No hay productos registrados en el catálogo.')),
      );
    }

    final headers = ['Ref / SKU', 'Artículo / Descripción', 'Stock', 'Precio'];
    final data = products.map((p) {
      final isAvail = p.isAvailable ? '' : ' [PAUSADO]';
      final stockLabel = p.stock != null ? (p.stock! > 0 ? '${p.stock}' : 'Agotado') : 'Disponible';
      final cat = p.category != null && p.category!.trim().isNotEmpty ? '[${p.category!.trim()}] ' : '';
      final details = p.details.trim().isNotEmpty ? '\n${p.details.trim()}' : '';
      final ref = (p.sku != null && p.sku!.trim().isNotEmpty) ? p.sku!.trim() : p.id;
      return [ref, '$cat${p.name}$isAvail$details', stockLabel, p.priceLabel];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(90),
      },
    );
  }

  static pw.Widget _buildFooter(BusinessFacts facts, String waLink) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('¿Cómo comprar?', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal900)),
                pw.SizedBox(height: 4),
                if (facts.payments.isNotEmpty)
                  pw.Text('• Métodos de pago: ${facts.payments}', style: const pw.TextStyle(fontSize: 8)),
                if (facts.delivery.isNotEmpty)
                  pw.Text('• Envíos: ${facts.delivery}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Text('Escanea el código QR o escribe a nuestro WhatsApp para hacer tu pedido.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: waLink,
            width: 55,
            height: 55,
          ),
        ],
      ),
    );
  }
}
