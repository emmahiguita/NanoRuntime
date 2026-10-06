// QUÉ: obtiene métricas y series reales de una DataTable.
// CÓMO: prepara tablas grandes en un isolate y delega agregados al kernel C++.
// POR QUÉ: las gráficas dependen exclusivamente de filas verificables de la fuente.

import 'dart:isolate';

import '../domain/data_models.dart';
import '../domain/data_statistics.dart';
import '../infrastructure/native_statistics_gateway.dart';
import 'data_statistics_preparer.dart';

final class DataStatisticsService {
  final StatisticsPort statisticsPort;

  const DataStatisticsService({
    this.statisticsPort = const NativeStatisticsGateway(),
  });

  Future<DataStatisticsSnapshot> analyze(DataTable table) async {
    // El umbral evita pagar el costo de crear un isolate para tablas pequeñas.
    final cellCount = table.rowCount * table.columnCount;
    final prepared = cellCount > 10_000
        ? await Isolate.run(() => DataStatisticsPreparer.prepare(table))
        : DataStatisticsPreparer.prepare(table);
    final numericValues = prepared.numericValues;

    var engine = 'c++20';
    final summaries = <NumericColumnStatistics>[];
    for (final entry in numericValues.entries) {
      Map<String, dynamic> values;
      try {
        values = await statisticsPort.summarize(entry.value);
      } catch (_) {
        engine = 'dart-fallback';
        values = _summarizeInDart(entry.value);
      }
      summaries.add(_toStatistics(entry.key, values));
    }

    final firstSeries = numericValues.entries.firstOrNull;
    return DataStatisticsSnapshot(
      rows: table.rowCount,
      columns: table.columnCount,
      nullCells: prepared.nullCells,
      numeric: summaries,
      categoryColumn: prepared.categoryColumn,
      categories: prepared.categories,
      seriesColumn: firstSeries?.key,
      seriesLabelColumn: prepared.seriesLabelColumn,
      series: firstSeries?.value.take(60).toList() ?? const [],
      seriesLabels: prepared.seriesLabels.take(60).toList(),
      quality: prepared.quality,
      engine: numericValues.isEmpty ? 'sin columnas numéricas' : engine,
    );
  }

  static NumericColumnStatistics _toStatistics(
    String column,
    Map<String, dynamic> data,
  ) {
    double number(String key) => (data[key] as num?)?.toDouble() ?? 0;
    return NumericColumnStatistics(
      column: column,
      count: number('count').round(),
      sum: number('sum'),
      min: number('min'),
      max: number('max'),
      mean: number('mean'),
      standardDeviation: number('stddev'),
    );
  }

  static Map<String, dynamic> _summarizeInDart(List<double> values) {
    if (values.isEmpty) {
      return const {
        'count': 0,
        'sum': 0,
        'min': 0,
        'max': 0,
        'mean': 0,
        'stddev': 0,
      };
    }
    var sum = 0.0, mean = 0.0, m2 = 0.0, min = values.first, max = values.first;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      sum += value;
      if (value < min) min = value;
      if (value > max) max = value;
      final delta = value - mean;
      mean += delta / (i + 1);
      m2 += delta * (value - mean);
    }
    return {
      'count': values.length,
      'sum': sum,
      'min': min,
      'max': max,
      'mean': mean,
      'stddev': values.length > 1 ? _sqrt(m2 / (values.length - 1)) : 0,
    };
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    var estimate = value > 1 ? value : 1.0;
    for (var i = 0; i < 20; i++) {
      estimate = (estimate + value / estimate) / 2;
    }
    return estimate;
  }
}
