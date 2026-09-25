// csv_tsv_parser.dart
//
// QUÉ HACE:
// Parser robusto y rápido de hojas de cálculo CSV / TSV / DSV para el módulo de bases de datos.
//
// CÓMO FUNCIONA:
// - Detecta automáticamente delimitadores (coma, punto y coma, tabulación o pipe).
// - Procesa campos delimitados con comillas y saltos de línea embebidos.
// - Infiere dinámicamente tipos de datos (enteros, decimales, booleanos y texto).
//
// POR QUÉ:
// Permite importar archivos del dispositivo o volcados de shell a `DataTable` de forma fiable (< 180 líneas).

library;

import '../domain/data_models.dart';

class CsvTsvParser {
  /// Analiza el contenido CSV/TSV y retorna un [DataTable] estructurado.
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
    if (rawLines.isEmpty) return DataTable(name: name, columns: [], rows: []);

    final headerTokens = _tokenizeLine(rawLines.first, delimiter);
    final columns = headerTokens.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (columns.isEmpty) return DataTable(name: name, columns: [], rows: []);

    final rows = <List<dynamic>>[];
    for (int i = 1; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;
      final tokens = _tokenizeLine(line, delimiter);
      final row = <dynamic>[];
      for (int c = 0; c < columns.length; c++) {
        row.add(c < tokens.length ? _inferValue(tokens[c].trim()) : null);
      }
      rows.add(row);
    }

    final columnTypes = <String, DataColumnType>{};
    for (int c = 0; c < columns.length; c++) {
      columnTypes[columns[c]] = _detectColumnType(rows, c);
    }

    return DataTable(name: name, columns: columns, rows: rows, columnTypes: columnTypes);
  }

  static String _detectDelimiter(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    int comma = 0, tab = 0, semi = 0, pipe = 0;
    bool inQuotes = false;
    for (int i = 0; i < firstLine.length; i++) {
      final ch = firstLine[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == ',') comma++;
        if (ch == '\t') tab++;
        if (ch == ';') semi++;
        if (ch == '|') pipe++;
      }
    }
    if (tab > comma && tab > semi) return '\t';
    if (semi > comma && semi > pipe) return ';';
    if (pipe > comma) return '|';
    return ',';
  }

  static List<String> _splitCsvLines(String content) {
    final lines = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          buffer.write('""');
          i++;
        } else {
          inQuotes = !inQuotes;
          buffer.write(char);
        }
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') i++;
        lines.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) lines.add(buffer.toString());
    return lines;
  }

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

  static dynamic _inferValue(String val) {
    if (val.isEmpty) return '';
    if (val.toLowerCase() == 'true') return true;
    if (val.toLowerCase() == 'false') return false;
    final intVal = int.tryParse(val);
    if (intVal != null) return intVal;
    final doubleVal = double.tryParse(val.replaceAll(',', '.'));
    if (doubleVal != null && !doubleVal.isNaN && !doubleVal.isInfinite) return doubleVal;
    return val;
  }

  static DataColumnType _detectColumnType(List<List<dynamic>> rows, int colIdx) {
    if (rows.isEmpty) return DataColumnType.text;
    int intCount = 0, realCount = 0, boolCount = 0, valid = 0;
    for (final row in rows) {
      if (colIdx >= row.length) continue;
      final val = row[colIdx];
      if (val == null || (val is String && val.isEmpty)) continue;
      valid++;
      if (val is int) {
        intCount++;
      } else if (val is double) {
        realCount++;
      } else if (val is bool) {
        boolCount++;
      }
    }
    if (valid == 0) return DataColumnType.text;
    if (intCount == valid) return DataColumnType.integer;
    if ((intCount + realCount) == valid) return DataColumnType.real;
    if (boolCount == valid) return DataColumnType.boolean;
    return DataColumnType.text;
  }
}
