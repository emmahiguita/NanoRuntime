// QUÉ: construye el resumen ejecutivo del PDF.
// CÓMO: presenta métricas, SQL y notas provenientes de la sesión real.
// POR QUÉ: separa contenido ejecutivo de tablas y gráficas (SRP).

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/data_models.dart';
import 'pdf_report_widgets.dart';
import 'report_text_formatter.dart';

abstract final class PdfOverviewSection {
  static List<pw.Widget> build(
    DataTable table,
    DataReportConfig config,
    int? executionTimeMs,
  ) => [
    _heading('Resumen ejecutivo'),
    pw.SizedBox(height: 8),
    pw.Row(
      children: [
        PdfReportWidgets.metric(
          'Total de registros',
          '${table.rowCount}',
          PdfReportWidgets.accent,
        ),
        pw.SizedBox(width: 10),
        PdfReportWidgets.metric(
          'Columnas',
          '${table.columnCount}',
          PdfReportWidgets.primary,
        ),
        if (executionTimeMs != null) ...[
          pw.SizedBox(width: 10),
          PdfReportWidgets.metric(
            'Latencia SQL',
            '$executionTimeMs ms',
            PdfColors.green700,
          ),
        ],
      ],
    ),
    if (config.queryUsed?.trim().isNotEmpty == true) ...[
      pw.SizedBox(height: 10),
      _textBox('Consulta SQL', config.queryUsed!),
    ],
    if (config.notes?.trim().isNotEmpty == true) ...[
      pw.SizedBox(height: 8),
      _textBox('Notas y conclusiones', config.notes!),
    ],
    pw.SizedBox(height: 14),
  ];

  static pw.Widget _heading(String value) => pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfReportWidgets.primary,
    ),
  );

  static pw.Widget _textBox(String label, String value) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfReportWidgets.background,
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: PdfReportWidgets.border, width: 0.5),
    ),
    child: pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800),
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: ReportTextFormatter.clean(value, maxLength: 1000)),
        ],
      ),
    ),
  );
}
