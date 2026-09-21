import 'dart:async';
import 'dart:io';
import '../domain/data_models.dart';
import '../../../core/services/terminal_dependencies.dart';

/// Motor de ejecución de consultas SQL tanto para hojas de cálculo en memoria como para bases de datos SQLite en Shell
class SqlQueryEngine {
  /// Ejecuta una consulta SQL sobre un mapa de tablas en memoria
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
        final resultTable = _processSelect(trimmedQuery, tables);
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

  /// Ejecuta una consulta SQL en una base de datos SQLite real a través de Shell / CLI
  static Future<QueryResult> executeShellSqliteQuery({
    required String dbPath,
    required String query,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Intentar ejecutar mediante shell_executor o process directo
      final shell = TerminalDependencies.instance.shell;
      final safeQuery = query.replaceAll('"', r'\"');
      final cmd = 'sqlite3 -header -csv "$dbPath" "$safeQuery"';

      String output = '';
      if (shell != null && shell.initialized) {
        final result = await shell.bash(cmd);
        output = result.stdout.isNotEmpty ? result.stdout : result.stderr;
      } else {
        // Fallback directo con Process.run si sqlite3 está en PATH
        final res = await Process.run('sqlite3', ['-header', '-csv', dbPath, query]);
        output = res.stdout.toString();
        if (res.exitCode != 0 && output.isEmpty) {
          output = res.stderr.toString();
        }
      }

      stopwatch.stop();

      if (output.trim().isEmpty) {
        return QueryResult.success(
          query: query,
          table: const DataTable(name: 'result', columns: ['Resultado'], rows: []),
          executionTimeMs: stopwatch.elapsedMilliseconds,
          affectedRows: 0,
        );
      }

      // Si empieza con error de sqlite3
      if (output.startsWith('Error:')) {
        return QueryResult.error(query, output.trim(), executionTimeMs: stopwatch.elapsedMilliseconds);
      }

      // Parsear la salida CSV de sqlite3
      final lines = output.trim().split('\n');
      if (lines.isEmpty) {
        return QueryResult.success(
          query: query,
          table: const DataTable(name: 'result', columns: [], rows: []),
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      final columns = lines.first.split(',').map((c) => c.trim().replaceAll('"', '')).toList();
      final rows = <List<dynamic>>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        rows.add(line.split(',').map((v) => v.trim().replaceAll('"', '')).toList());
      }

      return QueryResult.success(
        query: query,
        table: DataTable(name: 'sqlite_query', columns: columns, rows: rows),
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return QueryResult.error(query, 'Fallo al ejecutar en SQLite Shell: $e', executionTimeMs: stopwatch.elapsedMilliseconds);
    }
  }

  // --- Procesador SELECT en memoria ---

  static DataTable _processSelect(String query, Map<String, DataTable> tables) {
    // Normalizar espaciado
    final clean = query.replaceAll(RegExp(r'\s+'), ' ').replaceAll(';', '').trim();

    // Extraer clausulas con expresiones regulares
    final selectMatch = RegExp(r'^SELECT\s+(.*?)\s+FROM\s+([a-zA-Z0-9_]+)(.*)$', caseSensitive: false).firstMatch(clean);
    if (selectMatch == null) {
      throw const FormatException('Sintaxis inválida. Formato esperado: SELECT <columnas> FROM <tabla> [WHERE ...] [ORDER BY ...] [LIMIT ...]');
    }

    final selectClause = selectMatch.group(1)!.trim();
    final tableName = selectMatch.group(2)!.trim();
    final rest = selectMatch.group(3)!.trim();

    // Obtener tabla
    DataTable? sourceTable = tables[tableName];
    if (sourceTable == null) {
      // Buscar case-insensitive
      for (final entry in tables.entries) {
        if (entry.key.toLowerCase() == tableName.toLowerCase()) {
          sourceTable = entry.value;
          break;
        }
      }
    }

    if (sourceTable == null) {
      throw Exception('La tabla "$tableName" no existe. Tablas disponibles: ${tables.keys.join(", ")}');
    }

    var workingRows = List<List<dynamic>>.from(sourceTable.rows);

    // 1. WHERE
    final whereMatch = RegExp(r'WHERE\s+(.*?)(?:\s+(?:GROUP BY|ORDER BY|LIMIT)\b|$)', caseSensitive: false).firstMatch(rest);
    if (whereMatch != null) {
      final condition = whereMatch.group(1)!.trim();
      workingRows = _applyWhere(condition, workingRows, sourceTable.columns);
    }

    // 2. Proyección y Agregaciones (COUNT, SUM, AVG, MIN, MAX)
    final isAggregation = RegExp(r'\b(COUNT|SUM|AVG|MIN|MAX)\s*\(', caseSensitive: false).hasMatch(selectClause);

    if (isAggregation) {
      return _applyAggregation(selectClause, workingRows, sourceTable);
    }

    // 3. ORDER BY
    final orderMatch = RegExp(r'ORDER\s+BY\s+(.*?)(?:\s+LIMIT\b|$)', caseSensitive: false).firstMatch(rest);
    if (orderMatch != null) {
      final orderClause = orderMatch.group(1)!.trim();
      workingRows = _applyOrderBy(orderClause, workingRows, sourceTable.columns);
    }

    // 4. LIMIT y OFFSET
    final limitMatch = RegExp(r'LIMIT\s+(\d+)(?:\s+OFFSET\s+(\d+))?', caseSensitive: false).firstMatch(rest);
    if (limitMatch != null) {
      final limit = int.parse(limitMatch.group(1)!);
      final offset = limitMatch.group(2) != null ? int.parse(limitMatch.group(2)!) : 0;
      if (offset < workingRows.length) {
        final end = (offset + limit).clamp(0, workingRows.length);
        workingRows = workingRows.sublist(offset, end);
      } else {
        workingRows = [];
      }
    }

    // 5. Columnas Seleccionadas
    if (selectClause == '*' || selectClause == '${sourceTable.name}.*') {
      return sourceTable.copyWith(name: 'result_${sourceTable.name}', rows: workingRows);
    }

    final requestedCols = selectClause.split(',').map((c) => c.trim()).toList();
    final colIndices = <int>[];
    final finalColNames = <String>[];

    for (final col in requestedCols) {
      final cleanCol = col.replaceAll('`', '').replaceAll('"', '');
      final idx = sourceTable.columns.indexWhere((c) => c.equalsIgnoreCase(cleanCol));
      if (idx != -1) {
        colIndices.add(idx);
        finalColNames.add(sourceTable.columns[idx]);
      } else {
        // Podría ser un literal o no existir
        finalColNames.add(cleanCol);
        colIndices.add(-1);
      }
    }

    final projectedRows = workingRows.map((row) {
      return colIndices.map((idx) => idx >= 0 && idx < row.length ? row[idx] : null).toList();
    }).toList();

    return DataTable(
      name: 'result_${sourceTable.name}',
      columns: finalColNames,
      rows: projectedRows,
    );
  }

  static List<List<dynamic>> _applyWhere(String condition, List<List<dynamic>> rows, List<String> columns) {
    // Soporta condiciones simples y AND
    final subConditions = condition.split(RegExp(r'\s+AND\s+', caseSensitive: false));

    return rows.where((row) {
      for (final sub in subConditions) {
        if (!_evaluateCondition(sub.trim(), row, columns)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  static bool _evaluateCondition(String cond, List<dynamic> row, List<String> columns) {
    // Operadores: >=, <=, !=, <>, =, >, <, LIKE
    final opMatch = RegExp(r'^([a-zA-Z0-9_]+)\s*(=|!=|<>|>=|<=|>|<|LIKE)\s*(.*)$', caseSensitive: false).firstMatch(cond);
    if (opMatch == null) return true;

    final colName = opMatch.group(1)!.trim();
    final operator = opMatch.group(2)!.toUpperCase();
    var targetValStr = opMatch.group(3)!.trim();

    // Remover comillas del valor objetivo
    if ((targetValStr.startsWith("'") && targetValStr.endsWith("'")) ||
        (targetValStr.startsWith('"') && targetValStr.endsWith('"'))) {
      targetValStr = targetValStr.substring(1, targetValStr.length - 1);
    }

    final colIdx = columns.indexWhere((c) => c.equalsIgnoreCase(colName));
    if (colIdx == -1 || colIdx >= row.length) return false;

    final cellValue = row[colIdx];
    if (cellValue == null) return false;

    // Comparación numérica si es posible
    final numCell = double.tryParse(cellValue.toString());
    final numTarget = double.tryParse(targetValStr);

    if (numCell != null && numTarget != null) {
      switch (operator) {
        case '=': return numCell == numTarget;
        case '!=':
        case '<>': return numCell != numTarget;
        case '>': return numCell > numTarget;
        case '<': return numCell < numTarget;
        case '>=': return numCell >= numTarget;
        case '<=': return numCell <= numTarget;
      }
    }

    // Comparación de texto
    final strCell = cellValue.toString().toLowerCase();
    final strTarget = targetValStr.toLowerCase();

    switch (operator) {
      case '=': return strCell == strTarget;
      case '!=':
      case '<>': return strCell != strTarget;
      case 'LIKE':
        final pattern = strTarget.replaceAll('%', '.*');
        return RegExp('^$pattern\$').hasMatch(strCell);
      default:
        return strCell == strTarget;
    }
  }

  static List<List<dynamic>> _applyOrderBy(String orderClause, List<List<dynamic>> rows, List<String> columns) {
    final parts = orderClause.split(RegExp(r'\s+'));
    final colName = parts[0].replaceAll('`', '').replaceAll('"', '').trim();
    final isDesc = parts.length > 1 && parts[1].equalsIgnoreCase('DESC');

    final colIdx = columns.indexWhere((c) => c.equalsIgnoreCase(colName));
    if (colIdx == -1) return rows;

    final sorted = List<List<dynamic>>.from(rows);
    sorted.sort((a, b) {
      final valA = colIdx < a.length ? a[colIdx] : null;
      final valB = colIdx < b.length ? b[colIdx] : null;

      if (valA == null && valB == null) return 0;
      if (valA == null) return isDesc ? 1 : -1;
      if (valB == null) return isDesc ? -1 : 1;

      final numA = double.tryParse(valA.toString());
      final numB = double.tryParse(valB.toString());

      int cmp;
      if (numA != null && numB != null) {
        cmp = numA.compareTo(numB);
      } else {
        cmp = valA.toString().compareTo(valB.toString());
      }

      return isDesc ? -cmp : cmp;
    });

    return sorted;
  }

  static DataTable _applyAggregation(String selectClause, List<List<dynamic>> rows, DataTable source) {
    // Ejemplo: COUNT(*), SUM(total), AVG(precio), MIN(cantidad), MAX(cantidad)
    final aggMatch = RegExp(r'^(COUNT|SUM|AVG|MIN|MAX)\s*\(\s*(.*?)\s*\)$', caseSensitive: false).firstMatch(selectClause);

    if (aggMatch == null) {
      throw const FormatException('Sintaxis de agregación no válida. Formato: COUNT(*), SUM(columna), AVG(columna), MIN(columna), MAX(columna)');
    }

    final func = aggMatch.group(1)!.toUpperCase();
    final colTarget = aggMatch.group(2)!.trim();

    if (func == 'COUNT') {
      return DataTable(
        name: 'count_${source.name}',
        columns: ['COUNT'],
        rows: [[rows.length]],
      );
    }

    final colIdx = source.columns.indexWhere((c) => c.equalsIgnoreCase(colTarget));
    if (colIdx == -1) {
      throw Exception('Columna "$colTarget" no encontrada para la función $func');
    }

    final numbers = rows
        .map((r) => colIdx < r.length ? double.tryParse(r[colIdx]?.toString() ?? '') : null)
        .whereType<double>()
        .toList();

    dynamic resultVal = 0;
    if (numbers.isNotEmpty) {
      switch (func) {
        case 'SUM':
          resultVal = numbers.reduce((a, b) => a + b);
          break;
        case 'AVG':
          resultVal = (numbers.reduce((a, b) => a + b) / numbers.length).toStringAsFixed(2);
          break;
        case 'MIN':
          resultVal = numbers.reduce((a, b) => a < b ? a : b);
          break;
        case 'MAX':
          resultVal = numbers.reduce((a, b) => a > b ? a : b);
          break;
      }
    }

    return DataTable(
      name: '${func.toLowerCase()}_${source.name}',
      columns: ['$func($colTarget)'],
      rows: [[resultVal]],
    );
  }
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
