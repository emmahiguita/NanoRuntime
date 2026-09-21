import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/data_models.dart';

/// Servicio de generación, visualización y exportación de informes ejecutivos en PDF
class ReportGeneratorService {
  /// Genera un documento PDF con diseño profesional, resumen ejecutivo y tabla paginada
  static Future<Uint8List> generatePdfReport({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    final pdf = pw.Document(
      title: config.title,
      author: config.author,
      creator: 'NanoAI Data Studio',
    );

    // Formatear datos para la tabla PDF
    final headers = table.columns;
    // Limitar filas para el reporte PDF para prevenir saturación de memoria si hay miles
    final maxPdfRows = table.rows.length > 500 ? 500 : table.rows.length;
    final dataRows = table.rows.take(maxPdfRows).map((row) {
      return row.map((cell) => cell?.toString() ?? '-').toList();
    }).toList();

    // Colores del reporte
    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF0EA5E9); // Sky 500
    const lightBg = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const borderColor = PdfColor.fromInt(0xFFE2E8F0); // Slate 200

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      config.companyName,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      config.title,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    if (config.subtitle.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        config.subtitle,
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generado: ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Origen: ${table.name}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    if (config.author.isNotEmpty)
                      pw.Text(
                        'Autor: ${config.author}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'NanoAI Enterprise Local Analytics Studio — Documento Confidencial',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // Resumen Ejecutivo / Métricas clave
          if (config.includeSummaryMetrics) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                _buildMetricCard('Total Registros', '${table.rowCount}', accentColor),
                pw.SizedBox(width: 12),
                _buildMetricCard('Columnas', '${table.columnCount}', primaryColor),
                pw.SizedBox(width: 12),
                if (executionTimeMs != null)
                  _buildMetricCard('Latencia SQL', '${executionTimeMs}ms', PdfColors.green700),
              ],
            ),
            if (config.queryUsed != null && config.queryUsed!.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.RichText(
                  text: pw.TextSpan(
                    text: 'SQL Query: ',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentColor),
                    children: [
                      pw.TextSpan(
                        text: config.queryUsed!,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            pw.SizedBox(height: 16),
          ],

          // Tabla de Datos
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows,
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: primaryColor,
            ),
            rowDecoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: lightBg,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
          ),

          if (table.rows.length > maxPdfRows) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              '* Mostrando primeros $maxPdfRows registros de un total de ${table.rows.length}. Exporte a CSV completo para análisis masivo.',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetricCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF1F5F9),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el visor nativo de impresión y previsualización de PDF
  static Future<void> previewAndPrint({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return generatePdfReport(
          table: table,
          config: config,
          executionTimeMs: executionTimeMs,
        );
      },
      name: '${config.title.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Comparte el PDF mediante el selector del sistema Android/iOS
  static Future<void> sharePdfReport({
    required DataTable table,
    required DataReportConfig config,
    int? executionTimeMs,
  }) async {
    final bytes = await generatePdfReport(
      table: table,
      config: config,
      executionTimeMs: executionTimeMs,
    );

    final tempDir = await getTemporaryDirectory();
    final fileName = '${config.title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_')}_report.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: config.title,
      text: 'Informe generado con NanoAI Data Studio: ${config.title}',
    );
  }

  /// Guarda el informe o la tabla CSV en el directorio del shell de NanoAI
  static Future<String> saveToShellFilesystem({
    required String fileName,
    required String content,
    String? customPath,
  }) async {
    final targetPath = customPath ?? '/data/data/dev.nanoai.mobile/files/nano/$fileName';
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return targetPath;
  }
}
