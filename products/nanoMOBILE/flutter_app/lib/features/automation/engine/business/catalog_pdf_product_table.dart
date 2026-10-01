part of 'catalog_pdf_generator.dart';

// Construye la tabla del PDF con estados reales de inventario y disponibilidad.
pw.Widget _buildCatalogProductTable(List<BusinessProduct> products) {
  if (products.isEmpty) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 30),
      child: pw.Center(
        child: pw.Text('No hay productos registrados en el catálogo.'),
      ),
    );
  }

  final headers = ['Ref / SKU', 'Artículo / Descripción', 'Stock', 'Precio'];
  final data = products.map((product) {
    final availability = product.isAvailable ? '' : ' [PAUSADO]';
    final stock = product.stock;
    final stockLabel = stock == null
        ? 'Por confirmar'
        : stock > 0
        ? '$stock'
        : 'Agotado';
    final category = product.category?.trim() ?? '';
    final details = product.details.trim();
    final sku = product.sku?.trim() ?? '';
    return [
      sku.isEmpty ? product.id : sku,
      '${category.isEmpty ? '' : '[$category] '}${product.name}$availability${details.isEmpty ? '' : '\n$details'}',
      stockLabel,
      product.priceLabel,
    ];
  }).toList();

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: data,
    headerStyle: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 10,
    ),
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
