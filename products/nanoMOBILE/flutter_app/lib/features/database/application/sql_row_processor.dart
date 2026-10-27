// QUÉ: filtra y ordena filas para el SQL en memoria.
// CÓMO: evalúa comparadores tipados, LIKE y ORDER BY sobre índices resueltos.
// POR QUÉ: separa álgebra de filas del parser SELECT (SRP).

abstract final class SqlRowProcessor {
  static List<List<dynamic>> where(
    String condition,
    List<List<dynamic>> rows,
    List<String> columns,
  ) {
    final conditions = condition.split(
      RegExp(r'\s+AND\s+', caseSensitive: false),
    );
    return rows
        .where(
          (row) =>
              conditions.every((item) => _matches(item.trim(), row, columns)),
        )
        .toList();
  }

  static bool _matches(
    String condition,
    List<dynamic> row,
    List<String> columns,
  ) {
    final match = RegExp(
      r'^([a-zA-Z0-9_]+)\s*(=|!=|<>|>=|<=|>|<|LIKE)\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(condition);
    if (match == null) {
      throw FormatException('Condición WHERE inválida: $condition');
    }
    final column = match.group(1)!;
    final operator = match.group(2)!.toUpperCase();
    var target = match.group(3)!.trim();
    if ((target.startsWith("'") && target.endsWith("'")) ||
        (target.startsWith('"') && target.endsWith('"'))) {
      target = target.substring(1, target.length - 1);
    }
    final index = columns.indexWhere(
      (item) => item.toLowerCase() == column.toLowerCase(),
    );
    if (index < 0 || index >= row.length || row[index] == null) return false;
    final cell = row[index];
    final left = double.tryParse('$cell'), right = double.tryParse(target);
    if (left != null && right != null) {
      return switch (operator) {
        '=' => left == right,
        '!=' || '<>' => left != right,
        '>' => left > right,
        '<' => left < right,
        '>=' => left >= right,
        '<=' => left <= right,
        _ => false,
      };
    }
    final value = '$cell'.toLowerCase(), expected = target.toLowerCase();
    return switch (operator) {
      '=' => value == expected,
      '!=' || '<>' => value != expected,
      'LIKE' => RegExp(
        '^${RegExp.escape(expected).replaceAll(r'\%', '.*')}\$',
      ).hasMatch(value),
      _ => false,
    };
  }

  static List<List<dynamic>> order(
    String clause,
    List<List<dynamic>> rows,
    List<String> columns,
  ) {
    final parts = clause.split(RegExp(r'\s+'));
    final name = parts.first.replaceAll(RegExp(r'[`"]'), '');
    final descending = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
    final index = columns.indexWhere(
      (column) => column.toLowerCase() == name.toLowerCase(),
    );
    if (index < 0) {
      throw FormatException('Columna ORDER BY no encontrada: $name');
    }
    return [...rows]..sort((left, right) {
      final a = index < left.length ? left[index] : null;
      final b = index < right.length ? right[index] : null;
      if (a == null || b == null) return a == b ? 0 : (a == null ? 1 : -1);
      final numberA = double.tryParse('$a'), numberB = double.tryParse('$b');
      final result = numberA != null && numberB != null
          ? numberA.compareTo(numberB)
          : '$a'.compareTo('$b');
      return descending ? -result : result;
    });
  }
}
