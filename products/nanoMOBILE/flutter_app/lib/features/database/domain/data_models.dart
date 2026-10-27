// QUÉ: contratos de datos compartidos por dominio, aplicación y presentación.
// CÓMO: modelan tablas, resultados y configuración sin importar Flutter ni I/O.
// POR QUÉ: el dominio permanece intercambiable y comprobable (DIP/Clean Architecture).

import 'report_section.dart';

/// Tipos de datos admitidos en columnas de tablas y hojas de cálculo.
enum DataColumnType { text, integer, real, boolean, datetime }

/// Representación en memoria de una tabla de datos (procedente de CSV, TSV o SQL)
class DataTable {
  final String name;
  final List<String> columns;
  final List<List<dynamic>> rows;
  final Map<String, DataColumnType> columnTypes;

  final String? sourceUrl;
  final String? syncEndpointUrl;

  const DataTable({
    required this.name,
    required this.columns,
    required this.rows,
    this.columnTypes = const {},
    this.sourceUrl,
    this.syncEndpointUrl,
  });

  int get rowCount => rows.length;
  int get columnCount => columns.length;
  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
  bool get isGoogleSheet => sourceUrl?.contains('spreadsheets') ?? false;

  /// Actualiza el valor de una celda específica en memoria
  DataTable updateCell({
    required int rowIndex,
    required int columnIndex,
    required dynamic newValue,
  }) {
    if (rowIndex < 0 || rowIndex >= rows.length) return this;
    final newRows = List<List<dynamic>>.generate(rows.length, (i) {
      if (i != rowIndex) return rows[i];
      final newRow = List<dynamic>.from(rows[i]);
      if (columnIndex >= 0 && columnIndex < newRow.length) {
        newRow[columnIndex] = newValue;
      }
      return newRow;
    });
    return copyWith(rows: newRows);
  }

  /// Exporta los datos a formato CSV estándar con escape de comillas
  String toCsv({String delimiter = ','}) {
    final buffer = StringBuffer();
    // Cabeceras
    buffer.writeln(
      columns.map((c) => _escapeCsvValue(c, delimiter)).join(delimiter),
    );
    // Filas
    for (final row in rows) {
      buffer.writeln(
        row
            .map((val) => _escapeCsvValue(val?.toString() ?? '', delimiter))
            .join(delimiter),
      );
    }
    return buffer.toString();
  }

  /// Exporta a formato TSV (Tab Separated Values)
  String toTsv() => toCsv(delimiter: '\t');

  static String _escapeCsvValue(String value, String delimiter) {
    // Neutraliza fórmulas al abrir el CSV en Excel/Sheets (CSV injection).
    final safe = RegExp(r'^[\s]*[=+\-@]').hasMatch(value) ? "'$value" : value;
    if (safe.contains(delimiter) ||
        safe.contains('"') ||
        safe.contains('\n') ||
        safe.contains('\r')) {
      final escaped = safe.replaceAll('"', '""');
      return '"$escaped"';
    }
    return safe;
  }

  /// Crea una copia filtrada o proyectada
  DataTable copyWith({
    String? name,
    List<String>? columns,
    List<List<dynamic>>? rows,
    Map<String, DataColumnType>? columnTypes,
    String? sourceUrl,
    String? syncEndpointUrl,
  }) {
    return DataTable(
      name: name ?? this.name,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      columnTypes: columnTypes ?? this.columnTypes,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      syncEndpointUrl: syncEndpointUrl ?? this.syncEndpointUrl,
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
  final bool truncated;

  const QueryResult({
    required this.query,
    this.table,
    this.executionTimeMs = 0,
    this.errorMessage,
    this.affectedRows,
    this.truncated = false,
  });

  bool get isSuccess => errorMessage == null;
  bool get hasData => table != null && table!.isNotEmpty;
  int get rowCount => table?.rowCount ?? 0;

  factory QueryResult.error(
    String query,
    String error, {
    int executionTimeMs = 0,
  }) {
    return QueryResult(
      query: query,
      errorMessage: error,
      executionTimeMs: executionTimeMs,
    );
  }

  factory QueryResult.success({
    required String query,
    DataTable? table,
    int executionTimeMs = 0,
    int? affectedRows,
    bool truncated = false,
  }) {
    return QueryResult(
      query: query,
      table: table,
      executionTimeMs: executionTimeMs,
      affectedRows: affectedRows,
      truncated: truncated,
    );
  }
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
  final int maxRows;
  final List<ReportSection> sections;

  const DataReportConfig({
    required this.title,
    this.subtitle = 'Informe Generado por NanoAI Data Studio',
    this.author = 'NanoAI System',
    this.companyName = 'NanoAI Local Intelligence',
    this.queryUsed,
    this.notes,
    this.includeSummaryMetrics = true,
    this.includeTimestamp = true,
    this.maxRows = 500,
    this.sections = kDefaultReportSections,
  });
}
