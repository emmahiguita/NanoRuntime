// sql_memory_processor.dart
//
// QUÉ HACE:
// Procesador de consultas SELECT en memoria con soporte de WHERE, ORDER BY, LIMIT y agregaciones.
//
// CÓMO FUNCIONA:
// - Parsea la cláusula SELECT, FROM, WHERE, ORDER BY, LIMIT y OFFSET.
// - Evalúa filtros relacionales (=, !=, <>, >, <, >=, <=, LIKE) y operaciones AND.
// - Realiza ordenamientos ascendentes/descendentes y funciones de agregación (COUNT, SUM, AVG, MIN, MAX).
//
// POR QUÉ:
// Aplica SOLID (SRP) permitiendo ejecutar consultas SQL sobre cualquier `DataTable` sin requerir motor C++ externo (< 190 líneas).

library;

import '../domain/data_models.dart';

class SqlMemoryProcessor {
  static DataTable processSelect(String query, Map<String, DataTable> tables) {
    final clean = query.replaceAll(RegExp(r'\s+'), ' ').replaceAll(';', '').trim();
    final selectMatch = RegExp(r'^SELECT\s+(.*?)\s+FROM\s+([a-zA-Z0-9_]+)(.*)$', caseSensitive: false).firstMatch(clean);
    if (selectMatch == null) {
      throw const FormatException('Sintaxis inválida. Formato: SELECT <columnas> FROM <tabla> [WHERE ...] [ORDER BY ...] [LIMIT ...]');
    }

    final selectClause = selectMatch.group(1)!.trim();
    final tableName = selectMatch.group(2)!.trim();
    final rest = selectMatch.group(3)!.trim();

    DataTable? sourceTable = tables[tableName];
    if (sourceTable == null) {
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

    final whereMatch = RegExp(r'WHERE\s+(.*?)(?:\s+(?:GROUP BY|ORDER BY|LIMIT)\b|$)', caseSensitive: false).firstMatch(rest);
    if (whereMatch != null) {
      workingRows = _applyWhere(whereMatch.group(1)!.trim(), workingRows, sourceTable.columns);
    }

    final isAggregation = RegExp(r'\b(COUNT|SUM|AVG|MIN|MAX)\s*\(', caseSensitive: false).hasMatch(selectClause);
    if (isAggregation) {
      return _applyAggregation(selectClause, workingRows, sourceTable);
    }

    final orderMatch = RegExp(r'ORDER\s+BY\s+(.*?)(?:\s+LIMIT\b|$)', caseSensitive: false).firstMatch(rest);
    if (orderMatch != null) {
      workingRows = _applyOrderBy(orderMatch.group(1)!.trim(), workingRows, sourceTable.columns);
    }

    final limitMatch = RegExp(r'LIMIT\s+(\d+)(?:\s+OFFSET\s+(\d+))?', caseSensitive: false).firstMatch(rest);
    if (limitMatch != null) {
      final limit = int.parse(limitMatch.group(1)!);
      final offset = limitMatch.group(2) != null ? int.parse(limitMatch.group(2)!) : 0;
      workingRows = offset < workingRows.length
          ? workingRows.sublist(offset, (offset + limit).clamp(0, workingRows.length))
          : [];
    }

    if (selectClause == '*' || selectClause == '${sourceTable.name}.*') {
      return sourceTable.copyWith(name: 'result_${sourceTable.name}', rows: workingRows);
    }

    final requestedCols = selectClause.split(',').map((c) => c.trim()).toList();
    final colIndices = <int>[];
    final finalColNames = <String>[];

    for (final col in requestedCols) {
      final cleanCol = col.replaceAll('`', '').replaceAll('"', '');
      final idx = sourceTable.columns.indexWhere((c) => c.toLowerCase() == cleanCol.toLowerCase());
      colIndices.add(idx);
      finalColNames.add(idx != -1 ? sourceTable.columns[idx] : cleanCol);
    }

    final projectedRows = workingRows.map((row) {
      return colIndices.map((idx) => idx >= 0 && idx < row.length ? row[idx] : null).toList();
    }).toList();

    return DataTable(name: 'result_${sourceTable.name}', columns: finalColNames, rows: projectedRows);
  }

  static List<List<dynamic>> _applyWhere(String condition, List<List<dynamic>> rows, List<String> columns) {
    final subConditions = condition.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    return rows.where((row) => subConditions.every((sub) => _evaluateCondition(sub.trim(), row, columns))).toList();
  }

  static bool _evaluateCondition(String cond, List<dynamic> row, List<String> columns) {
    final opMatch = RegExp(r'^([a-zA-Z0-9_]+)\s*(=|!=|<>|>=|<=|>|<|LIKE)\s*(.*)$', caseSensitive: false).firstMatch(cond);
    if (opMatch == null) return true;

    final colName = opMatch.group(1)!.trim();
    final operator = opMatch.group(2)!.toUpperCase();
    var target = opMatch.group(3)!.trim();
    if ((target.startsWith("'") && target.endsWith("'")) || (target.startsWith('"') && target.endsWith('"'))) {
      target = target.substring(1, target.length - 1);
    }

    final colIdx = columns.indexWhere((c) => c.toLowerCase() == colName.toLowerCase());
    if (colIdx == -1 || colIdx >= row.length) return false;
    final cell = row[colIdx];
    if (cell == null) return false;

    final numCell = double.tryParse(cell.toString());
    final numTarget = double.tryParse(target);
    if (numCell != null && numTarget != null) {
      switch (operator) {
        case '=': return numCell == numTarget;
        case '!=': case '<>': return numCell != numTarget;
        case '>': return numCell > numTarget;
        case '<': return numCell < numTarget;
        case '>=': return numCell >= numTarget;
        case '<=': return numCell <= numTarget;
      }
    }

    final strCell = cell.toString().toLowerCase();
    final strTarget = target.toLowerCase();
    switch (operator) {
      case '=': return strCell == strTarget;
      case '!=': case '<>': return strCell != strTarget;
      case 'LIKE': return RegExp('^${strTarget.replaceAll('%', '.*')}\$').hasMatch(strCell);
      default: return strCell == strTarget;
    }
  }

  static List<List<dynamic>> _applyOrderBy(String orderClause, List<List<dynamic>> rows, List<String> columns) {
    final parts = orderClause.split(RegExp(r'\s+'));
    final colName = parts[0].replaceAll('`', '').replaceAll('"', '').trim();
    final isDesc = parts.length > 1 && parts[1].toLowerCase() == 'desc';
    final colIdx = columns.indexWhere((c) => c.toLowerCase() == colName.toLowerCase());
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
      final cmp = numA != null && numB != null ? numA.compareTo(numB) : valA.toString().compareTo(valB.toString());
      return isDesc ? -cmp : cmp;
    });
    return sorted;
  }

  static DataTable _applyAggregation(String selectClause, List<List<dynamic>> rows, DataTable source) {
    final aggMatch = RegExp(r'^(COUNT|SUM|AVG|MIN|MAX)\s*\(\s*(.*?)\s*\)$', caseSensitive: false).firstMatch(selectClause);
    if (aggMatch == null) throw const FormatException('Sintaxis de agregación no válida.');
    final func = aggMatch.group(1)!.toUpperCase();
    final colTarget = aggMatch.group(2)!.trim();

    if (func == 'COUNT') {
      return DataTable(name: 'count_${source.name}', columns: ['COUNT'], rows: [[rows.length]]);
    }

    final colIdx = source.columns.indexWhere((c) => c.toLowerCase() == colTarget.toLowerCase());
    if (colIdx == -1) throw Exception('Columna "$colTarget" no encontrada para $func');

    final numbers = rows.map((r) => colIdx < r.length ? double.tryParse(r[colIdx]?.toString() ?? '') : null).whereType<double>().toList();
    dynamic val = 0;
    if (numbers.isNotEmpty) {
      switch (func) {
        case 'SUM': val = numbers.reduce((a, b) => a + b); break;
        case 'AVG': val = (numbers.reduce((a, b) => a + b) / numbers.length).toStringAsFixed(2); break;
        case 'MIN': val = numbers.reduce((a, b) => a < b ? a : b); break;
        case 'MAX': val = numbers.reduce((a, b) => a > b ? a : b); break;
      }
    }
    return DataTable(name: '${func.toLowerCase()}_${source.name}', columns: ['$func($colTarget)'], rows: [[val]]);
  }
}
