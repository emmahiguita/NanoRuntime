/// Tipos de datos admitidos en columnas de tablas y hojas de cálculo
enum DataColumnType {
  text,
  integer,
  real,
  boolean,
  datetime,
}

/// Representación en memoria de una tabla de datos (procedente de CSV, TSV o SQL)
class DataTable {
  final String name;
  final List<String> columns;
  final List<List<dynamic>> rows;
  final Map<String, DataColumnType> columnTypes;

  const DataTable({
    required this.name,
    required this.columns,
    required this.rows,
    this.columnTypes = const {},
  });

  int get rowCount => rows.length;
  int get columnCount => columns.length;
  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;

  /// Exporta los datos a formato CSV estándar con escape de comillas
  String toCsv({String delimiter = ','}) {
    final buffer = StringBuffer();
    // Cabeceras
    buffer.writeln(columns.map((c) => _escapeCsvValue(c, delimiter)).join(delimiter));
    // Filas
    for (final row in rows) {
      buffer.writeln(row.map((val) => _escapeCsvValue(val?.toString() ?? '', delimiter)).join(delimiter));
    }
    return buffer.toString();
  }

  /// Exporta a formato TSV (Tab Separated Values)
  String toTsv() => toCsv(delimiter: '\t');

  static String _escapeCsvValue(String value, String delimiter) {
    if (value.contains(delimiter) || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Crea una copia filtrada o proyectada
  DataTable copyWith({
    String? name,
    List<String>? columns,
    List<List<dynamic>>? rows,
    Map<String, DataColumnType>? columnTypes,
  }) {
    return DataTable(
      name: name ?? this.name,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      columnTypes: columnTypes ?? this.columnTypes,
    );
  }
}

/// Resultado de la ejecución de una consulta SQL o filtro de hoja de cálculo
class QueryResult {
  final String query;
  final DataTable? table;
  final int executionTimeMs;
  final String? errorMessage;
  final int? affectedRows;

  const QueryResult({
    required this.query,
    this.table,
    this.executionTimeMs = 0,
    this.errorMessage,
    this.affectedRows,
  });

  bool get isSuccess => errorMessage == null;
  bool get hasData => table != null && table!.isNotEmpty;
  int get rowCount => table?.rowCount ?? 0;

  factory QueryResult.error(String query, String error, {int executionTimeMs = 0}) {
    return QueryResult(
      query: query,
      errorMessage: error,
      executionTimeMs: executionTimeMs,
    );
  }

  factory QueryResult.success({
    required String query,
    required DataTable table,
    int executionTimeMs = 0,
    int? affectedRows,
  }) {
    return QueryResult(
      query: query,
      table: table,
      executionTimeMs: executionTimeMs,
      affectedRows: affectedRows,
    );
  }
}

/// Origen de datos disponible en el estudio
enum DataSourceType {
  shellSpreadsheet,
  localSqlite,
  inMemory,
  sample,
}

class DataSourceItem {
  final String id;
  final String title;
  final String description;
  final DataSourceType type;
  final String? path;
  final int estimatedRows;

  const DataSourceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.path,
    this.estimatedRows = 0,
  });
}

/// Configuración para generar informes ejecutivos y tabulares en PDF
class DataReportConfig {
  final String title;
  final String subtitle;
  final String author;
  final String companyName;
  final String? queryUsed;
  final String? notes;
  final bool includeSummaryMetrics;
  final bool includeTimestamp;

  const DataReportConfig({
    required this.title,
    this.subtitle = 'Informe Generado por NanoAI Data Studio',
    this.author = 'NanoAI System',
    this.companyName = 'NanoAI Local Intelligence',
    this.queryUsed,
    this.notes,
    this.includeSummaryMetrics = true,
    this.includeTimestamp = true,
  });
}
