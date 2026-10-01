// QUÉ: resultados estadísticos que alimentan tarjetas y gráficas reales.
// CÓMO: separa resúmenes numéricos, distribución categórica y serie visible.
// POR QUÉ: la UI no calcula ni inventa métricas; solo representa este contrato.

class NumericColumnStatistics {
  final String column;
  final int count;
  final double sum;
  final double min;
  final double max;
  final double mean;
  final double standardDeviation;

  const NumericColumnStatistics({
    required this.column,
    required this.count,
    required this.sum,
    required this.min,
    required this.max,
    required this.mean,
    required this.standardDeviation,
  });
}

class CategoryFrequency {
  final String label;
  final int count;

  const CategoryFrequency(this.label, this.count);
}

class ColumnQuality {
  final String column;
  final int populated;
  final int missing;
  final String detectedType;

  const ColumnQuality({
    required this.column,
    required this.populated,
    required this.missing,
    required this.detectedType,
  });

  double get completeness {
    final total = populated + missing;
    return total == 0 ? 0 : populated / total;
  }
}

class DataStatisticsSnapshot {
  final int rows;
  final int columns;
  final int nullCells;
  final List<NumericColumnStatistics> numeric;
  final String? categoryColumn;
  final List<CategoryFrequency> categories;
  final String? seriesColumn;
  final List<double> series;
  final List<String> seriesLabels;
  final List<ColumnQuality> quality;
  final String engine;

  const DataStatisticsSnapshot({
    required this.rows,
    required this.columns,
    required this.nullCells,
    required this.numeric,
    required this.categories,
    required this.series,
    required this.seriesLabels,
    required this.quality,
    required this.engine,
    this.categoryColumn,
    this.seriesColumn,
  });

  double get completeness {
    final cells = rows * columns;
    return cells == 0 ? 0 : (cells - nullCells) / cells;
  }
}
