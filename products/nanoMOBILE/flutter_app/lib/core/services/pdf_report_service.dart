import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Servicio para la generación y exportación de informes PDF profesionales
/// a partir de respuestas, tablas, diagramas y análisis de NanoAI.
class PdfReportService {
  const PdfReportService._();

  /// Genera un informe PDF con estilo corporativo/técnico y abre el diálogo
  /// del sistema para previsualizar, imprimir o compartir el archivo.
  static Future<void> exportReport({
    required String title,
    required String content,
    required String modelName,
    DateTime? timestamp,
  }) async {
    final pdfBytes = await buildPdfBytes(
      title: title,
      content: content,
      modelName: modelName,
      timestamp: timestamp ?? DateTime.now(),
    );

    final cleanFileName =
        'informe_nanoai_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: cleanFileName);
  }

  /// Exporta el contenido del mensaje como archivo Markdown (.md) real y abre
  /// el diálogo de compartir del sistema. El archivo se escribe en el
  /// directorio temporal del dispositivo (limpiado por el SO; cero residuo).
  static Future<void> exportMarkdown({
    required String title,
    required String content,
    required String modelName,
    DateTime? timestamp,
  }) async {
    final ts = timestamp ?? DateTime.now();
    final dateStr =
        '${ts.day.toString().padLeft(2, '0')}/'
        '${ts.month.toString().padLeft(2, '0')}/'
        '${ts.year} '
        '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}';

    final mdBuffer = StringBuffer();
    mdBuffer.writeln('# $title');
    mdBuffer.writeln();
    mdBuffer.writeln(
      '> Generado por **NanoAI** · Modelo: `$modelName` · $dateStr',
    );
    mdBuffer.writeln();
    mdBuffer.writeln('---');
    mdBuffer.writeln();
    mdBuffer.writeln(content);
    mdBuffer.writeln();
    mdBuffer.writeln('---');
    mdBuffer.writeln(
      '*Generado on-device por NanoAI Engine (llama.cpp). Soberanía local.*',
    );

    final dir = await getTemporaryDirectory();
    final fileName =
        'informe_nanoai_${DateTime.now().millisecondsSinceEpoch}.md';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(mdBuffer.toString(), flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/markdown', name: fileName)],
        subject: title,
      ),
    );
  }

  /// Construye los bytes del documento PDF con tablas, diagramas y tipografía estructurada.
  static Future<Uint8List> buildPdfBytes({
    required String title,
    required String content,
    required String modelName,
    required DateTime timestamp,
  }) async {
    final doc = pw.Document();

    final dateStr =
        '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}/'
        '${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    final lines = content.split('\n');
    final widgets = <pw.Widget>[];

    var inCodeBlock = false;
    final codeBlockLines = <String>[];
    final tableLines = <List<String>>[];

    void flushTable() {
      if (tableLines.isEmpty) return;

      final data = <List<String>>[];
      for (final row in tableLines) {
        data.add(row);
      }

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.TableHelper.fromTextArray(
            headers: data.isNotEmpty ? data.first : null,
            data: data.length > 1 ? data.sublist(1) : const [],
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0A1929),
            ),
            rowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(
              fontSize: 8.5,
              color: PdfColors.black,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ),
      );
      tableLines.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Detección de bloques de código y diagramas
      if (trimmed.startsWith('```')) {
        flushTable();
        if (inCodeBlock) {
          widgets.add(
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF040E1A),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.fromBorderSide(
                  pw.BorderSide(
                    color: PdfColor.fromInt(0xFF0099CC),
                    width: 0.5,
                  ),
                ),
              ),
              child: pw.Text(
                codeBlockLines.join('\n'),
                style: pw.TextStyle(
                  color: const PdfColor.fromInt(0xFF21F2B2),
                  font: pw.Font.courier(),
                  fontSize: 8,
                  lineSpacing: 1.2,
                ),
              ),
            ),
          );
          codeBlockLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(line);
        continue;
      }

      // Detección de tablas Markdown (| col1 | col2 |)
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        // Ignorar fila divisoria |---|---|
        if (RegExp(r'^\|[\s\-:|]+\|$').hasMatch(trimmed)) {
          continue;
        }
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.isNotEmpty) {
          tableLines.add(cells);
          continue;
        }
      } else {
        flushTable();
      }

      // Encabezados y jerarquía
      if (trimmed.startsWith('# ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
            child: pw.Text(
              trimmed.substring(2),
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF0A1929),
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 3),
            child: pw.Text(
              trimmed.substring(3),
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF005588),
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('### ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
            child: pw.Text(
              trimmed.substring(4),
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF0077AA),
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '• ',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF0099CC),
                    fontSize: 10,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    trimmed.substring(2),
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.black,
                      lineSpacing: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (trimmed.startsWith('> ')) {
        // Citas / Callouts
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F5F9),
              border: pw.Border(
                left: pw.BorderSide(
                  color: PdfColor.fromInt(0xFF0099CC),
                  width: 3,
                ),
              ),
            ),
            child: pw.Text(
              trimmed.substring(2),
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey800,
              ),
            ),
          ),
        );
      } else if (trimmed.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            child: pw.Text(
              trimmed,
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.black,
                lineSpacing: 1.3,
              ),
            ),
          ),
        );
      }
    }

    flushTable();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColor.fromInt(0xFF0A1929),
                width: 1.5,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'NanoAI',
                    style: pw.TextStyle(
                      color: const PdfColor.fromInt(0xFF0A1929),
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    ' · Informe Técnico',
                    style: const pw.TextStyle(
                      color: PdfColors.grey700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Modelo: $modelName | $dateStr',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generado on-device mediante NanoAI Engine (llama.cpp). Soberanía local.',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 7.5,
                ),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 7.5,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.fromBorderSide(
                pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0)),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF0A1929),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Documento estructurado generado automáticamente por el motor de inferencia local.',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          ...widgets,
        ],
      ),
    );

    return doc.save();
  }
}
