import '../domain/data_models.dart';

/// Analizador rápido y robusto de hojas de cálculo CSV / TSV / DSV
class CsvTsvParser {
  /// Detecta automáticamente el delimitador y analiza el contenido de la hoja de cálculo
  static DataTable parse({
    required String name,
    required String rawContent,
    String? explicitDelimiter,
  }) {
    if (rawContent.trim().isEmpty) {
      return DataTable(name: name, columns: [], rows: []);
    }

    final delimiter = explicitDelimiter ?? _detectDelimiter(rawContent);
    final rawLines = _splitCsvLines(rawContent);

    if (rawLines.isEmpty) {
      return DataTable(name: name, columns: [], rows: []);
    }

    // Cabeceras
    final headerTokens = _tokenizeLine(rawLines.first, delimiter);
    final columns = headerTokens.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

    if (columns.isEmpty) {
      return DataTable(name: name, columns: [], rows: []);
    }

    final rows = <List<dynamic>>[];
    for (int i = 1; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;

      final tokens = _tokenizeLine(line, delimiter);
      final row = <dynamic>[];

      for (int c = 0; c < columns.length; c++) {
        if (c < tokens.length) {
          final rawVal = tokens[c].trim();
          row.add(_inferValue(rawVal));
        } else {
          row.add(null);
        }
      }
      rows.add(row);
    }

    // Inferir tipos por columna
    final columnTypes = <String, DataColumnType>{};
    for (int c = 0; c < columns.length; c++) {
      final colName = columns[c];
      columnTypes[colName] = _detectColumnType(rows, c);
    }

    return DataTable(
      name: name,
      columns: columns,
      rows: rows,
      columnTypes: columnTypes,
    );
  }

  /// Detecta el delimitador analizando la primera línea representativa
  static String _detectDelimiter(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );

    int commaCount = 0;
    int tabCount = 0;
    int semicolonCount = 0;
    int pipeCount = 0;

    bool inQuotes = false;
    for (int i = 0; i < firstLine.length; i++) {
      final ch = firstLine[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == ',') commaCount++;
        if (ch == '\t') tabCount++;
        if (ch == ';') semicolonCount++;
        if (ch == '|') pipeCount++;
      }
    }

    if (tabCount > commaCount && tabCount > semicolonCount) return '\t';
    if (semicolonCount > commaCount && semicolonCount > pipeCount) return ';';
    if (pipeCount > commaCount) return '|';
    return ',';
  }

  /// Divide el contenido respetando saltos de línea dentro de campos entre comillas
  static List<String> _splitCsvLines(String content) {
    final lines = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        // Chequeo de comilla escapada ("")
        if (i + 1 < content.length && content[i + 1] == '"') {
          buffer.write('""');
          i++; // Saltamos la siguiente comilla
        } else {
          inQuotes = !inQuotes;
          buffer.write(char);
        }
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        lines.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      lines.add(buffer.toString());
    }

    return lines;
  }

  /// Descompone una línea en celdas respetando comillas y delimitador
  static List<String> _tokenizeLine(String line, String delimiter) {
    final tokens = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (line.startsWith(delimiter, i) && !inQuotes) {
        tokens.add(current.toString());
        current.clear();
        i += delimiter.length - 1;
      } else {
        current.write(char);
      }
    }

    tokens.add(current.toString());
    return tokens;
  }

  /// Infiere si un texto es entero, decimal, booleano o texto plano
  static dynamic _inferValue(String val) {
    if (val.isEmpty) return '';
    if (val.equalsIgnoreCase('true')) return true;
    if (val.equalsIgnoreCase('false')) return false;

    // Entero
    final intVal = int.tryParse(val);
    if (intVal != null) return intVal;

    // Decimal (acepta coma o punto)
    final normalizedDecimal = val.replaceAll(',', '.');
    final doubleVal = double.tryParse(normalizedDecimal);
    if (doubleVal != null && !doubleVal.isNaN && !doubleVal.isInfinite) {
      return doubleVal;
    }

    return val;
  }

  static DataColumnType _detectColumnType(List<List<dynamic>> rows, int columnIndex) {
    if (rows.isEmpty) return DataColumnType.text;

    int intCount = 0;
    int realCount = 0;
    int boolCount = 0;
    int totalValid = 0;

    for (final row in rows) {
      if (columnIndex >= row.length) continue;
      final val = row[columnIndex];
      if (val == null || (val is String && val.isEmpty)) continue;

      totalValid++;
      if (val is int) {
        intCount++;
      } else if (val is double) {
        realCount++;
      } else if (val is bool) {
        boolCount++;
      }
    }

    if (totalValid == 0) return DataColumnType.text;
    if (intCount == totalValid) return DataColumnType.integer;
    if ((intCount + realCount) == totalValid) return DataColumnType.real;
    if (boolCount == totalValid) return DataColumnType.boolean;

    return DataColumnType.text;
  }
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
