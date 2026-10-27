// QUÉ: traduce el orden editable a widgets concretos del documento.
// CÓMO: despacha cada tipo a una sección especializada y reutilizable.
// POR QUÉ: evita condicionales gráficos dentro del generador principal.

import 'package:pdf/widgets.dart' as pw;
import '../domain/data_models.dart';
import '../domain/data_statistics.dart';
import '../domain/report_section.dart';
import 'pdf_chart_sections.dart';
import 'pdf_data_table_section.dart';
import 'pdf_overview_section.dart';
import 'pdf_statistics_section.dart';

abstract final class PdfReportSectionBuilder {
  static List<pw.Widget> build({
    required DataTable table,
    required DataReportConfig config,
    required DataStatisticsSnapshot statistics,
    required int? executionTimeMs,
  }) {
    final widgets = <pw.Widget>[];
    for (final section in config.sections) {
      widgets.addAll(
        _section(section, table, config, statistics, executionTimeMs),
      );
    }
    return widgets;
  }

  static List<pw.Widget> _section(
    ReportSection section,
    DataTable table,
    DataReportConfig config,
    DataStatisticsSnapshot statistics,
    int? executionTimeMs,
  ) => switch (section) {
    ReportSection.overview when config.includeSummaryMetrics =>
      PdfOverviewSection.build(table, config, executionTimeMs),
    ReportSection.overview => const <pw.Widget>[],
    ReportSection.numericStatistics => PdfStatisticsSection.numeric(statistics),
    ReportSection.distribution => PdfChartSections.distribution(statistics),
    ReportSection.trend => PdfChartSections.trend(statistics),
    ReportSection.quality => PdfStatisticsSection.quality(statistics),
    ReportSection.dataTable => PdfDataTableSection.build(table, config),
  };
}
