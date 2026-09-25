// pdf_document_builder.dart
//
// QUÉ HACE:
// Construye el documento PDF estructurado (páginas, encabezados, métricas y tabla de datos).
//
// CÓMO FUNCIONA:
// - Configura formato A4 apaisado con márgenes profesionales.
// - Inserta encabezados de empresa, resumen ejecutivo con tarjetas de métricas y la consulta SQL ejecutada.
// - Renderiza la cuadrícula de datos paginada con alternancia de colores de fila.
//
// POR QUÉ:
// Aplica SRP aislando la composición gráfica del documento PDF para mantener el archivo en < 180 líneas.

library;

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/data_models.dart';

class PdfDocumentBuilder {
  static const primaryColor = PdfColor.fromInt(0xFF0F172A);
  static const accentColor = PdfColor.fromInt(0xFF0EA5E9);
  static const lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const borderColor = PdfColor.fromInt(0xFFE2E8F0);

  static Future<Uint8List> buildPdf({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    final pdf = pw.Document(title: config.title, author: config.author, creator: 'NanoAI Data Studio');
    final maxRows = table.rows.length > 500 ? 500 : table.rows.length;
    final dataRows = table.rows.take(maxRows).map((r) => r.map((c) => c?.toString() ?? '-').toList()).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(config, table),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          if (config.includeSummaryMetrics) ...[
            pw.SizedBox(height: 12),
            pw.Row(children: [
              _metricCard('Total Registros', '${table.rowCount}', accentColor),
              pw.SizedBox(width: 12),
              _metricCard('Columnas', '${table.columnCount}', primaryColor),
              pw.SizedBox(width: 12),
              if (executionTimeMs != null) _metricCard('Latencia SQL', '${executionTimeMs}ms', PdfColors.green700),
            ]),
            if (config.queryUsed?.isNotEmpty == true) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(color: lightBg, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: borderColor, width: 0.5)),
                child: pw.Text('SQL: ${config.queryUsed}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800)),
              ),
            ],
            if (config.notes?.isNotEmpty == true) ...[
              pw.SizedBox(height: 8),
              pw.Text('Conclusiones: ${config.notes}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
            ],
            pw.SizedBox(height: 16),
          ],
          pw.TableHelper.fromTextArray(
            headers: table.columns,
            data: dataRows,
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: lightBg),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildHeader(DataReportConfig config, DataTable table) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(config.companyName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentColor)),
          pw.SizedBox(height: 2),
          pw.Text(config.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          if (config.subtitle.isNotEmpty) pw.Text(config.subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Generado: ${DateTime.now().toIso8601String().substring(0, 16).replaceAll("T", " ")}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Origen: ${table.name}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          if (config.author.isNotEmpty) pw.Text('Autor: ${config.author}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ]),
      ]),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('NanoAI Enterprise Local Analytics Studio — Documento Confidencial', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
      ]),
    );
  }

  static pw.Widget _metricCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(color: lightBg, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: borderColor, width: 0.5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      ]),
    );
  }
}
