// QUÉ: coordina formatos de salida para una tabla ya consultada.
// CÓMO: configura CSV/TSV/HTML/PDF y delega escritura/compartición.
// POR QUÉ: el controlador de estado no debe conocer detalles de documentos.

import '../domain/data_models.dart';
import 'data_export_service.dart';
import 'report_generator_service.dart';

final class DatabaseReportCoordinator {
  final DataExportService exporter;
  const DatabaseReportCoordinator({this.exporter = const DataExportService()});

  Future<String> delimited(DataTable table, {bool tsv = false}) =>
      exporter.exportDelimited(table, tsv: tsv);

  Future<String> html(DataTable table, {String? title, String? query}) =>
      exporter.exportHtml(
        table,
        DataReportConfig(
          title: title ?? 'Informe ${table.name}',
          queryUsed: query,
        ),
      );

  Future<String> pdf(
    DataTable table, {
    String? title,
    String? notes,
    String? query,
    int? executionTimeMs,
  }) => exporter.exportPdf(
    table,
    DataReportConfig(
      title: title ?? 'Informe ${table.name}',
      queryUsed: query,
      notes: notes,
    ),
    executionTimeMs: executionTimeMs,
  );

  Future<void> share(DataTable table, {String? title}) =>
      ReportGeneratorService.shareReport(
        table: table,
        config: DataReportConfig(title: title ?? 'Informe ${table.name}'),
      );
}
