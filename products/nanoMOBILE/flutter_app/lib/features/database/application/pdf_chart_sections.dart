// QUÉ: genera dos gráficas PDF a partir del snapshot estadístico real.
// CÓMO: escala frecuencias y serie sin inventar puntos ni interpolarlos.
// POR QUÉ: las visualizaciones exportadas deben ser verificables con la tabla.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/data_statistics.dart';
import 'pdf_report_widgets.dart';
import 'report_text_formatter.dart';

abstract final class PdfChartSections {
  static List<pw.Widget> distribution(DataStatisticsSnapshot data) {
    if (data.categories.isEmpty) {
      return _empty(
        'Distribución por categoría',
        'No hay una columna categórica.',
      );
    }
    final maximum = data.categories.fold<int>(
      1,
      (current, item) => item.count > current ? item.count : current,
    );
    return [
      _heading('Distribución · ${data.categoryColumn}'),
      pw.SizedBox(height: 8),
      for (final item in data.categories)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 120,
                child: pw.Text(
                  ReportTextFormatter.clean(item.label, maxLength: 28),
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ),
              pw.Container(
                width: 220 * item.count / maximum,
                height: 9,
                decoration: pw.BoxDecoration(
                  color: PdfReportWidgets.accent,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                '${item.count} · ${_percent(item.count, data.rows)}',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          ),
        ),
      pw.SizedBox(height: 14),
    ];
  }

  static List<pw.Widget> trend(DataStatisticsSnapshot data) {
    if (data.series.isEmpty) {
      return _empty('Serie y tendencia', 'No hay una columna numérica.');
    }
    final points = _sample(data);
    final values = points.map((point) => point.$2).toList(growable: false);
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final span = maximum - minimum;
    final axis = data.seriesLabelColumn == null
        ? '${data.seriesColumn}'
        : '${data.seriesColumn} por ${data.seriesLabelColumn}';
    return [
      _heading('Serie · $axis'),
      pw.SizedBox(height: 4),
      pw.Text(
        'Mínimo ${_number(minimum)} · Máximo ${_number(maximum)} · '
        '${data.series.length} puntos disponibles',
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        height: 125,
        padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfReportWidgets.border, width: 0.5),
          color: PdfReportWidgets.background,
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final point in points)
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      _number(point.$2),
                      style: const pw.TextStyle(fontSize: 5.5),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      width: 12,
                      height: span == 0
                          ? 58
                          : 18 + 62 * (point.$2 - minimum) / span,
                      color: PdfReportWidgets.accent,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      ReportTextFormatter.clean(point.$1, maxLength: 8),
                      style: const pw.TextStyle(fontSize: 5.2),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  // Reduce solo la densidad visual; cada barra conserva un punto real.
  static List<(String, double)> _sample(DataStatisticsSnapshot data) {
    final count = data.series.length > 18 ? 18 : data.series.length;
    return List.generate(count, (position) {
      final index = count == 1
          ? 0
          : ((data.series.length - 1) * position / (count - 1)).round();
      final label = index < data.seriesLabels.length
          ? data.seriesLabels[index]
          : '${index + 1}';
      return (label, data.series[index]);
    }, growable: false);
  }

  static List<pw.Widget> _empty(String title, String message) => [
    _heading(title),
    pw.SizedBox(height: 5),
    pw.Text(message, style: const pw.TextStyle(fontSize: 8)),
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

  static String _percent(int count, int total) =>
      total == 0 ? '0%' : '${(count * 100 / total).toStringAsFixed(1)}%';

  static String _number(double value) =>
      value.abs() >= 1000 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}
