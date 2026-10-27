part of 'persona_import.dart';

/// Parser CSV separado para mantener el pipeline pequeño y legible.
/// QUÉ HACE: valida columnas, autoría explícita y comillas CSV reales.
/// CÓMO: transforma cada fila en mensajes; filas generadas cortan el par.
/// POR QUÉ: una importación no debe adivinar quién escribió el mensaje.
extension _PersonaImportCsv on PersonaImportPipeline {
  void _parseCsv({
    required String normalizedContent,
    required List<_Message> messages,
    required List<String> warnings,
    required void Function(String role, String text, int at) addMessage,
  }) {
    final table = _csv(normalizedContent);
    if (table.isEmpty) throw const FormatException('CSV vacío.');
    final header = table.first.map((s) => s.trim().toLowerCase()).toList();
    final roleIndex = header.indexOf('role'),
        textIndex = header.indexOf('text'),
        timeIndex = header.indexOf('timestamp');
    if (header.toSet().length != header.length) {
      throw const FormatException('CSV con nombres de columna duplicados.');
    }
    if (roleIndex < 0 || textIndex < 0) {
      throw const FormatException(
        'CSV requiere columnas role,text y timestamp opcional.',
      );
    }
    for (final row in table.skip(1)) {
      if (row.every((v) => v.trim().isEmpty)) continue;
      if (row.length != header.length) {
        throw const FormatException('CSV con columnas incompletas.');
      }
      final role = row[roleIndex].trim().toLowerCase();
      if (_PersonaImportUtils._generatedRow(Map.fromIterables(header, row))) {
        messages.add(const _Message('break', '', 0));
        warnings.add('Salida generada excluida.');
        continue;
      }
      if (role != 'owner' && role != 'contact') {
        throw const FormatException('CSV: role debe ser owner o contact.');
      }
      addMessage(
        role,
        row[textIndex],
        timeIndex < 0 ? 0 : _PersonaImportUtils._timestamp(row[timeIndex]),
      );
    }
  }

  static List<List<String>> _csv(String source) {
    final header = source.split('\n').first;
    var inQuotes = false, commas = 0, semicolons = 0;
    for (var i = 0; i < header.length; i++) {
      if (header[i] == '"') {
        if (inQuotes && i + 1 < header.length && header[i + 1] == '"') {
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes) {
        if (header[i] == ',') commas++;
        if (header[i] == ';') semicolons++;
      }
    }
    final delimiter = semicolons > commas ? ';' : ',';
    final result = <List<String>>[];
    var row = <String>[], cell = StringBuffer(), quoted = false, closed = false;
    for (var i = 0; i < source.length; i++) {
      final c = source[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          cell.write(c);
        }
      } else if (c == delimiter || c == '\n') {
        row.add(cell.toString());
        cell = StringBuffer();
        closed = false;
        if (c == '\n') {
          result.add(row);
          row = [];
        }
      } else if (c == '"') {
        if (closed || cell.isNotEmpty) {
          throw const FormatException(
            'CSV: una celda con comillas debe estar entre comillas dobles; escapa las interiores duplicándolas.',
          );
        }
        quoted = true;
      } else if (closed) {
        if (c != ' ' && c != '\t') {
          throw const FormatException(
            'CSV: contenido después de cerrar una celda con comillas.',
          );
        }
      } else {
        cell.write(c);
      }
    }
    if (quoted) throw const FormatException('Comillas CSV sin cerrar.');
    if (cell.isNotEmpty || row.isNotEmpty || closed) {
      row.add(cell.toString());
      result.add(row);
    }
    return result;
  }
}
