// QUÉ: ejecuta GROUP BY y múltiples agregaciones SQL sobre DataTable.
// CÓMO: agrupa filas por claves y evalúa COUNT/SUM/AVG/MIN/MAX por proyección.
// POR QUÉ: las consultas sugeridas por la propia UI deben producir datos reales.

import '../domain/data_models.dart';
import 'sql_projection.dart';

abstract final class SqlAggregationProcessor {
  static DataTable process({
    required String selectClause,
    required String trailingClause,
    required List<List<dynamic>> rows,
    required DataTable source,
  }) {
    final groupMatch = RegExp(
      r'GROUP\s+BY\s+(.*?)(?:\s+(?:ORDER BY|LIMIT)\b|$)',
      caseSensitive: false,
    ).firstMatch(trailingClause);
    final groups = groupMatch == null
        ? const <String>[]
        : _split(groupMatch.group(1)!).map(_identifier).toList();
    final projections = _split(selectClause).map(SqlProjection.parse).toList();
    final groupIndexes = groups
        .map((name) => _columnIndex(source, name))
        .toList();
    final buckets = <String, List<List<dynamic>>>{};
    for (final row in rows) {
      final key = groupIndexes
          .map((index) => index < row.length ? row[index] : null)
          .join('\u001f');
      buckets.putIfAbsent(key, () => []).add(row);
    }
    if (rows.isEmpty && groups.isEmpty) buckets[''] = [];

    var resultRows = <List<dynamic>>[];
    for (final bucket in buckets.values) {
      resultRows.add([
        for (final projection in projections)
          _evaluateProjection(projection, bucket, source, groups),
      ]);
    }
    final columns = projections.map((projection) => projection.label).toList();
    resultRows = _order(resultRows, columns, trailingClause);
    resultRows = _limit(resultRows, trailingClause);
    return DataTable(
      name: 'aggregate_${source.name}',
      columns: columns,
      rows: resultRows,
    );
  }

  static dynamic _evaluateProjection(
    SqlProjection projection,
    List<List<dynamic>> rows,
    DataTable source,
    List<String> groups,
  ) {
    if (projection.function == null) {
      final column = _identifier(projection.expression);
      if (!groups.any((group) => group.toLowerCase() == column.toLowerCase())) {
        throw FormatException(
          'La columna "$column" debe aparecer en GROUP BY.',
        );
      }
      final index = _columnIndex(source, column);
      return rows.isEmpty || index >= rows.first.length
          ? null
          : rows.first[index];
    }
    if (projection.function == 'COUNT' && projection.expression.trim() == '*') {
      return rows.length;
    }
    final values = rows
        .map((row) => _expressionValue(projection.expression, row, source))
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    if (projection.function == 'COUNT') return values.length;
    if (values.isEmpty) return 0;
    switch (projection.function) {
      case 'SUM':
        return values.fold<double>(0, (sum, value) => sum + value);
      case 'AVG':
        return values.fold<double>(0, (sum, value) => sum + value) /
            values.length;
      case 'MIN':
        return values.reduce((a, b) => a < b ? a : b);
      case 'MAX':
        return values.reduce((a, b) => a > b ? a : b);
    }
    throw FormatException('Agregación no soportada: ${projection.function}');
  }

  static num? _expressionValue(
    String expression,
    List<dynamic> row,
    DataTable source,
  ) {
    final match = RegExp(
      r'^(.+?)\s*([*\/+-])\s*(.+)$',
    ).firstMatch(expression.trim());
    if (match == null) return _operand(expression, row, source);
    final left = _operand(match.group(1)!, row, source);
    final right = _operand(match.group(3)!, row, source);
    if (left == null || right == null) return null;
    switch (match.group(2)) {
      case '*':
        return left * right;
      case '/':
        return right == 0 ? null : left / right;
      case '+':
        return left + right;
      case '-':
        return left - right;
    }
    return null;
  }

  static num? _operand(String raw, List<dynamic> row, DataTable source) {
    final literal = num.tryParse(raw.trim());
    if (literal != null) return literal;
    final index = _columnIndex(source, _identifier(raw));
    if (index >= row.length) return null;
    final value = row[index];
    return value is num ? value : num.tryParse('$value');
  }

  static List<List<dynamic>> _order(
    List<List<dynamic>> rows,
    List<String> columns,
    String clause,
  ) {
    final match = RegExp(
      r'ORDER\s+BY\s+([^\s,]+)(?:\s+(ASC|DESC))?',
      caseSensitive: false,
    ).firstMatch(clause);
    if (match == null) return rows;
    final index = columns.indexWhere(
      (column) =>
          column.toLowerCase() == _identifier(match.group(1)!).toLowerCase(),
    );
    if (index < 0) return rows;
    final descending = match.group(2)?.toUpperCase() == 'DESC';
    final result = [...rows]
      ..sort((a, b) {
        final left = a[index], right = b[index];
        final comparison = left is num && right is num
            ? left.compareTo(right)
            : '$left'.compareTo('$right');
        return descending ? -comparison : comparison;
      });
    return result;
  }

  static List<List<dynamic>> _limit(List<List<dynamic>> rows, String clause) {
    final match = RegExp(
      r'LIMIT\s+(\d+)(?:\s+OFFSET\s+(\d+))?',
      caseSensitive: false,
    ).firstMatch(clause);
    if (match == null) return rows;
    final limit = int.parse(match.group(1)!);
    final offset = int.tryParse(match.group(2) ?? '') ?? 0;
    if (offset >= rows.length) return [];
    return rows.sublist(offset, (offset + limit).clamp(0, rows.length));
  }

  static List<String> _split(String value) {
    final parts = <String>[];
    var depth = 0, start = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '(') depth++;
      if (value[i] == ')') depth--;
      if (value[i] == ',' && depth == 0) {
        parts.add(value.substring(start, i).trim());
        start = i + 1;
      }
    }
    parts.add(value.substring(start).trim());
    return parts;
  }

  static int _columnIndex(DataTable table, String name) {
    final index = table.columns.indexWhere(
      (column) => column.toLowerCase() == name.toLowerCase(),
    );
    if (index < 0) throw FormatException('Columna "$name" no encontrada.');
    return index;
  }

  static String _identifier(String raw) =>
      raw.trim().replaceAll(RegExp(r'[`"]'), '');
}
