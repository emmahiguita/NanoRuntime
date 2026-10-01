// QUÉ: clasifica columnas y prepara series verificables desde una DataTable.
// CÓMO: recorre cada celda una sola vez y devuelve estructuras transferibles.
// POR QUÉ: mantiene el servicio coordinador pequeño y permite usar un isolate.

import '../domain/data_models.dart';
import '../domain/data_statistics.dart';

typedef PreparedStatistics = ({
  Map<String, List<double>> numericValues,
  int nullCells,
  String? categoryColumn,
  List<CategoryFrequency> categories,
  List<String> seriesLabels,
  List<ColumnQuality> quality,
});

abstract final class DataStatisticsPreparer {
  static PreparedStatistics prepare(DataTable table) {
    final numericValues = <String, List<double>>{};
    final quality = <ColumnQuality>[];
    var nullCells = 0;

    // Analiza tipo y completitud de cada columna con una pasada por sus filas.
    for (
      var columnIndex = 0;
      columnIndex < table.columns.length;
      columnIndex++
    ) {
      final values = <double>[];
      var populated = 0;
      for (final row in table.rows) {
        final value = columnIndex < row.length ? row[columnIndex] : null;
        if (value == null || '$value'.trim().isEmpty) {
          nullCells++;
          continue;
        }
        populated++;
        final number = value is num
            ? value.toDouble()
            : double.tryParse('$value');
        if (number != null && number.isFinite) values.add(number);
      }
      final isNumeric = populated > 0 && values.length == populated;
      if (isNumeric) numericValues[table.columns[columnIndex]] = values;
      quality.add(
        ColumnQuality(
          column: table.columns[columnIndex],
          populated: populated,
          missing: table.rowCount - populated,
          detectedType: isNumeric ? 'Numérico' : 'Texto / mixto',
        ),
      );
    }

    final category = _categoryDistribution(table, numericValues.keys.toSet());
    return (
      numericValues: numericValues,
      nullCells: nullCells,
      categoryColumn: category.$1,
      categories: category.$2,
      seriesLabels: _seriesLabels(table, numericValues, category.$1),
      quality: quality,
    );
  }

  // Alinea cada etiqueta con una fila numérica válida de la primera serie.
  static List<String> _seriesLabels(
    DataTable table,
    Map<String, List<double>> numericValues,
    String? categoryColumn,
  ) {
    final seriesIndex = table.columns.indexOf(
      numericValues.keys.firstOrNull ?? '',
    );
    final labelIndex = table.columns.indexOf(categoryColumn ?? '');
    final labels = <String>[];
    if (seriesIndex < 0) return labels;
    for (final row in table.rows) {
      final raw = seriesIndex < row.length ? row[seriesIndex] : null;
      final number = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (number == null || !number.isFinite) continue;
      labels.add(
        labelIndex >= 0 && labelIndex < row.length
            ? '${row[labelIndex] ?? labels.length + 1}'
            : '${labels.length + 1}',
      );
    }
    return labels;
  }

  // Usa la primera columna no numérica como distribución categórica visible.
  static (String?, List<CategoryFrequency>) _categoryDistribution(
    DataTable table,
    Set<String> numeric,
  ) {
    final index = table.columns.indexWhere(
      (column) => !numeric.contains(column),
    );
    if (index < 0) return (null, const []);
    final counts = <String, int>{};
    for (final row in table.rows) {
      final value = index < row.length
          ? '${row[index] ?? '(vacío)'}'
          : '(vacío)';
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return (
      table.columns[index],
      [
        for (final entry in sorted.take(8))
          CategoryFrequency(entry.key, entry.value),
      ],
    );
  }
}
