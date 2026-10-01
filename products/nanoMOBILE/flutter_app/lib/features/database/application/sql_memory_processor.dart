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
import 'sql_aggregation_processor.dart';
import 'sql_row_processor.dart';

class SqlMemoryProcessor {
  static DataTable processSelect(String query, Map<String, DataTable> tables) {
    final clean = query
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(';', '')
        .trim();
    final selectMatch = RegExp(
      r'^SELECT\s+(.*?)\s+FROM\s+([a-zA-Z0-9_]+)(.*)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (selectMatch == null) {
      throw const FormatException(
        'Sintaxis inválida. Formato: SELECT <columnas> FROM <tabla> [WHERE ...] [ORDER BY ...] [LIMIT ...]',
      );
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
      throw Exception(
        'La tabla "$tableName" no existe. Tablas disponibles: ${tables.keys.join(", ")}',
      );
    }

    var workingRows = List<List<dynamic>>.from(sourceTable.rows);

    final whereMatch = RegExp(
      r'WHERE\s+(.*?)(?:\s+(?:GROUP BY|ORDER BY|LIMIT)\b|$)',
      caseSensitive: false,
    ).firstMatch(rest);
    if (whereMatch != null) {
      workingRows = SqlRowProcessor.where(
        whereMatch.group(1)!.trim(),
        workingRows,
        sourceTable.columns,
      );
    }

    final isAggregation = RegExp(
      r'\b(COUNT|SUM|AVG|MIN|MAX)\s*\(',
      caseSensitive: false,
    ).hasMatch(selectClause);
    if (isAggregation) {
      return SqlAggregationProcessor.process(
        selectClause: selectClause,
        trailingClause: rest,
        rows: workingRows,
        source: sourceTable,
      );
    }

    final orderMatch = RegExp(
      r'ORDER\s+BY\s+(.*?)(?:\s+LIMIT\b|$)',
      caseSensitive: false,
    ).firstMatch(rest);
    if (orderMatch != null) {
      workingRows = SqlRowProcessor.order(
        orderMatch.group(1)!.trim(),
        workingRows,
        sourceTable.columns,
      );
    }

    final limitMatch = RegExp(
      r'LIMIT\s+(\d+)(?:\s+OFFSET\s+(\d+))?',
      caseSensitive: false,
    ).firstMatch(rest);
    if (limitMatch != null) {
      final limit = int.parse(limitMatch.group(1)!);
      final offset = limitMatch.group(2) != null
          ? int.parse(limitMatch.group(2)!)
          : 0;
      workingRows = offset < workingRows.length
          ? workingRows.sublist(
              offset,
              (offset + limit).clamp(0, workingRows.length),
            )
          : [];
    }

    if (selectClause == '*' || selectClause == '${sourceTable.name}.*') {
      return sourceTable.copyWith(
        name: 'result_${sourceTable.name}',
        rows: workingRows,
      );
    }

    final requestedCols = selectClause.split(',').map((c) => c.trim()).toList();
    final colIndices = <int>[];
    final finalColNames = <String>[];

    for (final col in requestedCols) {
      final cleanCol = col.replaceAll('`', '').replaceAll('"', '');
      final idx = sourceTable.columns.indexWhere(
        (c) => c.toLowerCase() == cleanCol.toLowerCase(),
      );
      colIndices.add(idx);
      finalColNames.add(idx != -1 ? sourceTable.columns[idx] : cleanCol);
    }

    final projectedRows = workingRows.map((row) {
      return colIndices
          .map((idx) => idx >= 0 && idx < row.length ? row[idx] : null)
          .toList();
    }).toList();

    return DataTable(
      name: 'result_${sourceTable.name}',
      columns: finalColNames,
      rows: projectedRows,
    );
  }
}
