import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../../database/domain/data_models.dart';

// excel_data_decoder.dart
//
// QUÉ HACE:
// Decodifica libros Excel modernos (.xlsx) directamente a estructuras DataTable de Nano.
//
// CÓMO FUNCIONA:
// - Descomprime la estructura ZIP OpenXML del archivo .xlsx en memoria.
// - Parsea sharedStrings.xml para recuperar cadenas de texto indexadas.
// - Lee la primera hoja de trabajo (sheet1.xml) extrayendo filas y celdas tipadas.
//
// POR QUÉ:
// Proporciona lectura rápida y 100% offline de inventarios sin depender de servicios web
// ni bibliotecas nativas pesadas, manteniendo el archivo por debajo de 200 líneas (SOLID - SRP).

class ExcelDataDecoder {
  /// Decodifica los bytes de un archivo .xlsx a un DataTable.
  static DataTable decodeXlsx({
    required Uint8List bytes,
    required String tableName,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedStrings = _loadSharedStrings(archive);

    ArchiveFile? sheetFile;
    for (final file in archive) {
      if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
        sheetFile = file;
        break;
      }
    }

    if (sheetFile == null) {
      return DataTable(name: tableName, columns: [], rows: []);
    }

    final sheetXml = utf8.decode(sheetFile.content as List<int>);
    final document = XmlDocument.parse(sheetXml);
    final rowElements = document.findAllElements('row');

    final rawGrid = <List<String>>[];
    for (final row in rowElements) {
      final cellElements = row.findAllElements('c');
      final rowValues = <String>[];

      for (final cell in cellElements) {
        final type = cell.getAttribute('t');
        final valueElement = cell.findElements('v').firstOrNull;
        String val = '';

        if (valueElement != null) {
          final rawText = valueElement.innerText.trim();
          if (type == 's') {
            final idx = int.tryParse(rawText);
            if (idx != null && idx >= 0 && idx < sharedStrings.length) {
              val = sharedStrings[idx];
            }
          } else {
            val = rawText;
          }
        } else {
          // Si no hay elemento <v>, buscar texto inline <is><t>
          final inlineText = cell.findAllElements('t').firstOrNull;
          if (inlineText != null) {
            val = inlineText.innerText.trim();
          }
        }
        rowValues.add(val);
      }

      if (rowValues.any((v) => v.isNotEmpty)) {
        rawGrid.add(rowValues);
      }
    }

    if (rawGrid.isEmpty) {
      return DataTable(name: tableName, columns: [], rows: []);
    }

    // Normalizar longitud de columnas
    final columns = rawGrid.first.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    final colCount = columns.length;
    final rows = <List<dynamic>>[];

    for (int i = 1; i < rawGrid.length; i++) {
      final line = rawGrid[i];
      final row = <dynamic>[];
      for (int c = 0; c < colCount; c++) {
        row.add(c < line.length ? line[c].trim() : '');
      }
      rows.add(row);
    }

    return DataTable(
      name: tableName,
      columns: columns,
      rows: rows,
    );
  }

  /// Extrae el diccionario de cadenas compartidas de OpenXML.
  static List<String> _loadSharedStrings(Archive archive) {
    final strings = <String>[];
    ArchiveFile? sharedFile;
    for (final f in archive) {
      if (f.name == 'xl/sharedStrings.xml') {
        sharedFile = f;
        break;
      }
    }
    if (sharedFile == null) return strings;

    try {
      final xmlContent = utf8.decode(sharedFile.content as List<int>);
      final doc = XmlDocument.parse(xmlContent);
      final stringItems = doc.findAllElements('si');

      for (final si in stringItems) {
        final textParts = si.findAllElements('t').map((t) => t.innerText);
        strings.add(textParts.join(''));
      }
    } catch (_) {
      // Ignorar fallos de formato en el diccionario opcional
    }
    return strings;
  }
}
