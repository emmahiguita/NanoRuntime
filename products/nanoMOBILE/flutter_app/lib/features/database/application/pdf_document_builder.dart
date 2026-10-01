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
import 'pdf_report_widgets.dart';

class PdfDocumentBuilder {
  static Future<Uint8List> buildPdf({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    final pdf = pw.Document(
      title: config.title,
      author: config.author,
      creator: 'NanoAI Data Studio',
    );
    final maxRows = table.rows.length > config.maxRows
        ? config.maxRows
        : table.rows.length;
    final dataRows = table.rows
        .take(maxRows)
        .map((r) => r.map((c) => c?.toString() ?? '-').toList())
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => PdfReportWidgets.header(config, table),
        footer: PdfReportWidgets.footer,
        build: (ctx) => [
          if (config.includeSummaryMetrics) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                PdfReportWidgets.metric(
                  'Total Registros',
                  '${table.rowCount}',
                  PdfReportWidgets.accent,
                ),
                pw.SizedBox(width: 12),
                PdfReportWidgets.metric('Columnas', '${table.columnCount}', PdfReportWidgets.primary),
                pw.SizedBox(width: 12),
                if (executionTimeMs != null)
                  PdfReportWidgets.metric(
                    'Latencia SQL',
                    '${executionTimeMs}ms',
                    PdfColors.green700,
                  ),
              ],
            ),
            if (config.queryUsed?.isNotEmpty == true) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfReportWidgets.background,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfReportWidgets.border, width: 0.5),
                ),
                child: pw.Text(
                  'SQL: ${config.queryUsed}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ),
            ],
            if (config.notes?.isNotEmpty == true) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Conclusiones: ${config.notes}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey800,
                ),
              ),
            ],
            pw.SizedBox(height: 16),
          ],
          if (table.rowCount > config.maxRows)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                'Vista limitada a ${config.maxRows} de ${table.rowCount} filas. La exportación CSV conserva todos los registros.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.orange800,
                ),
              ),
            ),
          pw.TableHelper.fromTextArray(
            headers: table.columns,
            data: dataRows,
            border: pw.TableBorder.all(color: PdfReportWidgets.border, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfReportWidgets.primary),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 4,
            ),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: PdfReportWidgets.background),
          ),
        ],
      ),
    );
    return pdf.save();
  }

}
