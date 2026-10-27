// QUÉ: ensambla el PDF desde secciones reales seleccionadas por el usuario.
// CÓMO: calcula estadísticas una vez, carga Inter y delega cada bloque.
// POR QUÉ: mantiene composición, cálculo y presentación desacoplados (SRP).

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/data_models.dart';
import 'data_statistics_service.dart';
import 'pdf_report_section_builder.dart';
import 'pdf_report_widgets.dart';

class PdfDocumentBuilder {
  static Future<Uint8List> buildPdf({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    // La misma instantánea alimenta KPIs, tablas y gráficas del documento.
    final statistics = await const DataStatisticsService().analyze(table);
    final fontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final inter = pw.Font.ttf(fontData);
    final pdf = pw.Document(
      title: config.title,
      author: config.author,
      creator: 'NanoAI Data Studio',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: inter, bold: inter),
        header: (_) => PdfReportWidgets.header(config, table),
        footer: PdfReportWidgets.footer,
        build: (_) => PdfReportSectionBuilder.build(
          table: table,
          config: config,
          statistics: statistics,
          executionTimeMs: executionTimeMs,
        ),
      ),
    );
    return pdf.save();
  }
}
