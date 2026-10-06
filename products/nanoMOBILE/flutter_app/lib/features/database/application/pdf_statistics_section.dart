// QUÉ: compone la sección estadística del reporte PDF.
// CÓMO: transforma el snapshot calculado en KPIs, tablas y barras imprimibles.
// POR QUÉ: el PDF comparte exactamente las cifras que presenta Data Studio.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/data_statistics.dart';
import 'pdf_report_widgets.dart';
import 'report_text_formatter.dart';

abstract final class PdfStatisticsSection {
  static List<pw.Widget> numeric(DataStatisticsSnapshot data) => [
    _heading('Estadísticas numéricas'),
    pw.SizedBox(height: 8),
    if (data.numeric.isEmpty)
      pw.Text(
        'No hay columnas numéricas.',
        style: const pw.TextStyle(fontSize: 8),
      )
    else
      _numericTable(data.numeric),
    pw.SizedBox(height: 14),
  ];

  static List<pw.Widget> quality(DataStatisticsSnapshot data) => [
    _heading('Calidad de datos'),
    pw.SizedBox(height: 8),
    pw.Row(
      children: [
        PdfReportWidgets.metric(
          'Completitud',
          '${(data.completeness * 100).toStringAsFixed(1)}%',
          PdfColors.green700,
        ),
        pw.SizedBox(width: 10),
        PdfReportWidgets.metric(
          'Celdas vacías',
          '${data.nullCells}',
          PdfColors.orange700,
        ),
        pw.SizedBox(width: 10),
        PdfReportWidgets.metric(
          'Motor estadístico',
          data.engine,
          PdfReportWidgets.accent,
        ),
      ],
    ),
    pw.SizedBox(height: 10),
    _qualityTable(data.quality),
    pw.SizedBox(height: 14),
  ];

  // Presenta mínimo, máximo, promedio y dispersión de cada columna numérica.
  static pw.Widget _numericTable(List<NumericColumnStatistics> values) =>
      pw.TableHelper.fromTextArray(
        headers: const [
          'Columna',
          'N',
          'Mínimo',
          'Máximo',
          'Promedio',
          'Desv. estándar',
        ],
        data: [
          for (final item in values)
            [
              ReportTextFormatter.clean(item.column, maxLength: 48),
              '${item.count}',
              _number(item.min),
              _number(item.max),
              _number(item.mean),
              _number(item.standardDeviation),
            ],
        ],
        headerDecoration: const pw.BoxDecoration(
          color: PdfReportWidgets.primary,
        ),
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellPadding: const pw.EdgeInsets.all(4),
        border: pw.TableBorder.all(color: PdfReportWidgets.border, width: 0.5),
      );

  // Tabla auditable: tipo detectado, celdas válidas, faltantes y porcentaje.
  static pw.Widget _qualityTable(List<ColumnQuality> values) =>
      pw.TableHelper.fromTextArray(
        headers: const ['Columna', 'Tipo', 'Completas', 'Faltantes', 'Calidad'],
        data: [
          for (final item in values)
            [
              ReportTextFormatter.clean(item.column, maxLength: 48),
              item.detectedType,
              '${item.populated}',
              '${item.missing}',
              '${(item.completeness * 100).toStringAsFixed(1)}%',
            ],
        ],
        headerDecoration: const pw.BoxDecoration(
          color: PdfReportWidgets.primary,
        ),
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellPadding: const pw.EdgeInsets.all(4),
        border: pw.TableBorder.all(color: PdfReportWidgets.border, width: 0.5),
      );

  static pw.Widget _heading(String value) => pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfReportWidgets.primary,
    ),
  );

  static String _number(double value) =>
      value.abs() >= 1000 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}
