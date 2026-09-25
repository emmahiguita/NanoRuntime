// report_generator_service.dart
//
// QUÉ HACE:
// Servicio para generación, previsualización, impresión y compartición de informes PDF.
//
// CÓMO FUNCIONA:
// - Delega la creación de bytes a `PdfDocumentBuilder`.
// - Provee `previewOrPrintReport` vía paquete `printing`.
// - Provee `shareReport` vía paquete `share_plus` y guardado en disco local.
//
// POR QUÉ:
// Aplica Clean Architecture y modularidad manteniendo el archivo en < 90 líneas.

library;

import 'dart:io';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/data_models.dart';
import 'pdf_document_builder.dart';

class ReportGeneratorService {
  /// Genera un documento PDF con diseño profesional y tabla paginada.
  static Future<Uint8List> generatePdfReport({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) => PdfDocumentBuilder.buildPdf(table: table, config: config, executionTimeMs: executionTimeMs);

  /// Abre la vista previa del sistema para imprimir o guardar como PDF.
  static Future<void> previewOrPrintReport({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    final pdfBytes = await generatePdfReport(
      table: table,
      config: config,
      executionTimeMs: executionTimeMs,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '${config.title.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"), "_")}.pdf',
    );
  }

  /// Comparte el informe PDF generado con otras aplicaciones.
  static Future<void> shareReport({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    final pdfBytes = await generatePdfReport(
      table: table,
      config: config,
      executionTimeMs: executionTimeMs,
    );
    final tempDir = await getTemporaryDirectory();
    final sanitizedTitle = config.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath = '${tempDir.path}/$sanitizedTitle.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/pdf', name: '$sanitizedTitle.pdf')],
        subject: 'Informe Ejecutivo: ${config.title}',
      ),
    );
  }

  /// Guarda el informe PDF en el directorio de documentos de la aplicación.
  static Future<String> saveReportToDisk({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    final pdfBytes = await generatePdfReport(
      table: table,
      config: config,
      executionTimeMs: executionTimeMs,
    );
    final docsDir = await getApplicationDocumentsDirectory();
    final sanitizedTitle = config.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath = '${docsDir.path}/$sanitizedTitle.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }
}
