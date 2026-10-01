// QUÉ: escribe CSV, TSV, HTML y PDF con nombres/extensiones correctos.
// CÓMO: usa un directorio data_exports y delega la composición de cada formato.
// POR QUÉ: separa I/O del controlador y entrega evidencia real mediante la ruta creada.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../domain/data_models.dart';
import 'html_report_builder.dart';
import 'report_generator_service.dart';

final class DataExportService {
  const DataExportService();

  Future<String> exportDelimited(DataTable table, {bool tsv = false}) async {
    final directory = await _directory();
    final extension = tsv ? 'tsv' : 'csv';
    final file = File('${directory.path}/${_fileName(table.name)}.$extension');
    await file.writeAsString(tsv ? table.toTsv() : table.toCsv(), flush: true);
    return file.path;
  }

  Future<String> exportHtml(DataTable table, DataReportConfig config) async {
    final directory = await _directory();
    final file = File('${directory.path}/${_fileName(config.title)}.html');
    await file.writeAsString(
      HtmlReportBuilder.build(table: table, config: config),
      flush: true,
    );
    return file.path;
  }

  Future<String> exportPdf(
    DataTable table,
    DataReportConfig config, {
    int? executionTimeMs,
  }) async {
    final directory = await _directory();
    final file = File('${directory.path}/${_fileName(config.title)}.pdf');
    final bytes = await ReportGeneratorService.generatePdfReport(
      table: table,
      config: config,
      executionTimeMs: executionTimeMs,
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/data_exports').create(recursive: true);
  }

  static String _fileName(String raw) {
    final safe = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return '${safe.isEmpty ? 'datos' : safe}_${DateTime.now().millisecondsSinceEpoch}';
  }
}
