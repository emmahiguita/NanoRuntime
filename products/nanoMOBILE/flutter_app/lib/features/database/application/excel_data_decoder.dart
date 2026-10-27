// QUÉ: decodifica la primera hoja XLSX a una DataTable conservando celdas vacías.
// CÓMO: lee OpenXML, shared strings y referencias A1 con límites anti zip-bomb.
// POR QUÉ: Excel es una fuente tabular; su adaptador pertenece a Data Studio.

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../domain/data_models.dart';

abstract final class ExcelDataDecoder {
  static const maxCompressedBytes = 20 * 1024 * 1024;
  static const maxExpandedBytes = 100 * 1024 * 1024;

  static DataTable decodeXlsx({
    required Uint8List bytes,
    required String tableName,
  }) {
    if (bytes.length > maxCompressedBytes) {
      throw const FormatException('El XLSX supera el límite seguro de 20 MB.');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final expanded = archive.fold<int>(0, (total, file) => total + file.size);
    if (expanded > maxExpandedBytes) {
      throw const FormatException(
        'El XLSX expandido supera el límite seguro de 100 MB.',
      );
    }
    final strings = _sharedStrings(archive);
    final sheet = archive.firstWhere(
      (file) =>
          file.name.startsWith('xl/worksheets/sheet') &&
          file.name.endsWith('.xml'),
      orElse: () => ArchiveFile.noCompress('', 0, const <int>[]),
    );
    if (sheet.name.isEmpty) {
      return DataTable(name: tableName, columns: const [], rows: const []);
    }

    final document = XmlDocument.parse(utf8.decode(sheet.content as List<int>));
    final grid = <List<String>>[];
    for (final row in document.findAllElements('row')) {
      final values = <String>[];
      var fallbackColumn = 0;
      for (final cell in row.findElements('c')) {
        final reference = cell.getAttribute('r');
        final column = reference == null
            ? fallbackColumn
            : _columnIndex(reference);
        while (values.length <= column) {
          values.add('');
        }
        values[column] = _cellValue(cell, strings);
        fallbackColumn = column + 1;
      }
      if (values.any((value) => value.isNotEmpty)) grid.add(values);
    }
    if (grid.isEmpty) {
      return DataTable(name: tableName, columns: const [], rows: const []);
    }

    final width = grid.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final columns = List<String>.generate(width, (index) {
      final value = index < grid.first.length ? grid.first[index].trim() : '';
      return value.isEmpty ? 'columna_${index + 1}' : value;
    });
    final rows = <List<dynamic>>[
      for (final line in grid.skip(1))
        [
          for (var index = 0; index < width; index++)
            index < line.length ? _infer(line[index]) : '',
        ],
    ];
    return DataTable(name: tableName, columns: columns, rows: rows);
  }

  static String _cellValue(XmlElement cell, List<String> strings) {
    final inline = cell.findAllElements('t').firstOrNull?.innerText;
    final raw = cell.findElements('v').firstOrNull?.innerText.trim();
    if (raw == null) return inline?.trim() ?? '';
    if (cell.getAttribute('t') == 's') {
      final index = int.tryParse(raw);
      return index != null && index < strings.length ? strings[index] : '';
    }
    return raw;
  }

  static List<String> _sharedStrings(Archive archive) {
    final matches = archive.where(
      (file) => file.name == 'xl/sharedStrings.xml',
    );
    if (matches.isEmpty) return const [];
    final document = XmlDocument.parse(
      utf8.decode(matches.first.content as List<int>),
    );
    return [
      for (final item in document.findAllElements('si'))
        item.findAllElements('t').map((node) => node.innerText).join(),
    ];
  }

  static int _columnIndex(String reference) {
    final letters =
        RegExp(r'^[A-Za-z]+').stringMatch(reference)?.toUpperCase() ?? 'A';
    var result = 0;
    for (final code in letters.codeUnits) {
      result = result * 26 + code - 64;
    }
    return result - 1;
  }

  static dynamic _infer(String value) {
    final trimmed = value.trim();
    return int.tryParse(trimmed) ?? double.tryParse(trimmed) ?? trimmed;
  }
}
