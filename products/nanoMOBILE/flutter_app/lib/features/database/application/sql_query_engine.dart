// sql_query_engine.dart
//
// QUÉ HACE:
// Fachada principal para ejecución de consultas SQL tanto en memoria como sobre SQLite real.
//
// CÓMO FUNCIONA:
// - Desvía consultas SELECT, SHOW TABLES y DESCRIBE a `SqlMemoryProcessor`.
// - Desvía consultas hacia archivos `.db` a `SqlShellExecutor`.
// - Mide tiempos exactos de ejecución en milisegundos (`Stopwatch`).
//
// POR QUÉ:
// Aplica el patrón Facade y SOLID manteniendo el archivo principal en < 90 líneas sin pérdida funcional.

library;

import '../domain/data_models.dart';
import 'sql_memory_processor.dart';
import 'sql_shell_executor.dart';

class SqlQueryEngine {
  /// Ejecuta una consulta SQL sobre un mapa de tablas en memoria.
  static QueryResult executeMemoryQuery({
    required String query,
    required Map<String, DataTable> tables,
  }) {
    final stopwatch = Stopwatch()..start();
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return QueryResult.error(query, 'La consulta SQL está vacía.');
    }

    try {
      final upper = trimmedQuery.toUpperCase();

      if (upper.startsWith('SELECT')) {
        final resultTable = SqlMemoryProcessor.processSelect(trimmedQuery, tables);
        stopwatch.stop();
        return QueryResult.success(
          query: query,
          table: resultTable,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      } else if (upper.startsWith('SHOW TABLES') || upper.startsWith('SELECT TABLE_NAME')) {
        final rows = tables.keys.map((k) => [k, tables[k]!.rowCount, tables[k]!.columnCount]).toList();
        stopwatch.stop();
        return QueryResult.success(
          query: query,
          table: DataTable(
            name: 'tables',
            columns: ['table_name', 'total_rows', 'total_columns'],
            rows: rows,
          ),
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      } else if (upper.startsWith('DESCRIBE') || upper.startsWith('DESC ')) {
        final parts = trimmedQuery.split(RegExp(r'\s+'));
        final tableName = parts.length > 1 ? parts[1].replaceAll(';', '').trim() : '';
        final table = tables[tableName] ?? tables.values.firstOrNull;
        if (table == null) {
          return QueryResult.error(query, 'Tabla "$tableName" no encontrada.');
        }

        final rows = table.columns.map((col) {
          final type = table.columnTypes[col]?.name ?? 'text';
          return [col, type, 'YES'];
        }).toList();

        stopwatch.stop();
        return QueryResult.success(
          query: query,
          table: DataTable(
            name: 'schema_${table.name}',
            columns: ['Column', 'Type', 'Nullable'],
            rows: rows,
          ),
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      return QueryResult.error(
        query,
        'Comando no soportado en memoria. Soporta SELECT, SHOW TABLES, DESCRIBE o use SQLite en Shell.',
      );
    } catch (e) {
      stopwatch.stop();
      return QueryResult.error(
        query,
        'Error de sintaxis SQL: $e',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Ejecuta una consulta SQL en una base de datos SQLite real.
  static Future<QueryResult> executeShellSqliteQuery({
    required String dbPath,
    required String query,
  }) => SqlShellExecutor.execute(dbPath: dbPath, query: query);
}
