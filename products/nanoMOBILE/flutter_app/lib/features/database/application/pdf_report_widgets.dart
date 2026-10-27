// QUÉ: componentes visuales reutilizables del reporte PDF.
// CÓMO: compone encabezado, pie y tarjetas con la paleta corporativa.
// POR QUÉ: PdfDocumentBuilder queda dedicado a estructura/paginación (SRP).

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/data_models.dart';
import 'report_text_formatter.dart';

abstract final class PdfReportWidgets {
  static const primary = PdfColor.fromInt(0xFF0F172A);
  static const accent = PdfColor.fromInt(0xFF0EA5E9);
  static const background = PdfColor.fromInt(0xFFF8FAFC);
  static const border = PdfColor.fromInt(0xFFE2E8F0);

  static pw.Widget header(
    DataReportConfig config,
    DataTable table,
  ) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              ReportTextFormatter.clean(config.companyName, maxLength: 60),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              ReportTextFormatter.clean(config.title, maxLength: 100),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            if (config.subtitle.isNotEmpty)
              pw.Text(
                ReportTextFormatter.clean(config.subtitle, maxLength: 120),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (config.includeTimestamp)
              pw.Text(
                'Generado: ${DateTime.now().toIso8601String().substring(0, 16).replaceAll("T", " ")}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            pw.Text(
              'Origen: ${ReportTextFormatter.clean(table.name, maxLength: 60)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            if (config.author.isNotEmpty)
              pw.Text(
                'Autor: ${ReportTextFormatter.clean(config.author, maxLength: 60)}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
          ],
        ),
      ],
    ),
  );

  static pw.Widget footer(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: border, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'NanoAI Local Analytics · Documento privado',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        ),
      ],
    ),
  );

  static pw.Widget metric(String label, String value, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: border, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
}
