// QUÉ: presenta una muestra paginada de los registros reales.
// CÓMO: limpia controles, adapta tipografía al ancho y alterna filas.
// POR QUÉ: una celda extensa o dañada no debe romper el documento completo.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/data_models.dart';
import 'pdf_report_widgets.dart';
import 'report_text_formatter.dart';

abstract final class PdfDataTableSection {
  static List<pw.Widget> build(DataTable table, DataReportConfig config) {
    final visibleRows = table.rows
        .take(config.maxRows)
        .map(
          (row) => row
              .map((cell) => ReportTextFormatter.clean(cell, maxLength: 120))
              .toList(growable: false),
        );
    final fontSize = table.columnCount > 12 ? 5.5 : 7.5;
    return [
      _heading(),
      if (table.rowCount > config.maxRows) ...[
        pw.SizedBox(height: 5),
        pw.Text(
          'Muestra de ${config.maxRows} de ${table.rowCount} filas. '
          'La exportación CSV conserva todos los registros.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange800),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: table.columns
            .map((value) => ReportTextFormatter.clean(value, maxLength: 60))
            .toList(growable: false),
        data: visibleRows.toList(growable: false),
        border: pw.TableBorder.all(color: PdfReportWidgets.border, width: 0.5),
        headerStyle: pw.TextStyle(
          fontSize: fontSize + 0.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfReportWidgets.primary,
        ),
        cellStyle: pw.TextStyle(fontSize: fontSize),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: const pw.BoxDecoration(
          color: PdfReportWidgets.background,
        ),
      ),
      pw.SizedBox(height: 12),
    ];
  }

  static pw.Widget _heading() => pw.Text(
    'Muestra tabular · datos reales',
    style: pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfReportWidgets.primary,
    ),
  );
}
