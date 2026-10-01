// QUÉ: importa CSV/TSV/XLSX y Google Sheets público a DataTable.
// CÓMO: valida tamaño/origen, decodifica y delega al parser adecuado.
// POR QUÉ: centraliza límites de red/archivo fuera del controlador y la UI.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import '../domain/data_models.dart';
import 'csv_tsv_parser.dart';
import 'excel_data_decoder.dart';

final class TabularImportService {
  static const maxBytes = 20 * 1024 * 1024;
  const TabularImportService();

  Future<DataTable> fromFile(String path) async {
    final file = File(path);
    final length = await file.length();
    if (length > maxBytes) {
      throw const FormatException(
        'El archivo supera el límite seguro de 20 MB.',
      );
    }
    final bytes = await file.readAsBytes();
    final name = _name(file.uri.pathSegments.last);
    if (path.toLowerCase().endsWith('.xlsx')) {
      // Descomprimir OpenXML fuera de UI evita cuadros congelados en archivos grandes.
      return Isolate.run(
        () => ExcelDataDecoder.decodeXlsx(bytes: bytes, tableName: name),
      );
    }
    // Decodificación y parseo recorren todo el archivo; se ejecutan en isolate.
    return Isolate.run(() {
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      return CsvTsvParser.parse(name: name, rawContent: content);
    });
  }

  Future<DataTable> fromPublicGoogleSheet(String rawUrl) async {
    final uri = Uri.parse(rawUrl.trim());
    if (uri.scheme != 'https' || uri.host != 'docs.google.com') {
      throw const FormatException(
        'Solo se admiten enlaces HTTPS de docs.google.com.',
      );
    }
    final match = RegExp(
      r'/spreadsheets/d/([a-zA-Z0-9-_]+)',
    ).firstMatch(uri.path);
    if (match == null) {
      throw const FormatException(
        'El enlace no contiene un ID de Google Sheets válido.',
      );
    }
    final fragmentGid = RegExp(
      r'(?:^|&)gid=(\d+)',
    ).firstMatch(uri.fragment)?.group(1);
    final gid = uri.queryParameters['gid'] ?? fragmentGid;
    final export = Uri.https(
      'docs.google.com',
      '/spreadsheets/d/${match.group(1)}/export',
      {'format': 'csv', if (gid != null) 'gid': gid},
    );
    final response = await http
        .get(export)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Google Sheets respondió HTTP ${response.statusCode}.');
    }
    if (response.bodyBytes.length > maxBytes) {
      throw const FormatException('La hoja supera el límite seguro de 20 MB.');
    }
    final tableName = 'google_sheet_${match.group(1)!.substring(0, 8)}';
    return Isolate.run(
      () => CsvTsvParser.parse(
        name: tableName,
        rawContent: utf8.decode(response.bodyBytes),
        explicitDelimiter: ',',
      ),
    );
  }

  static String _name(String fileName) => fileName
      .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')
      .toLowerCase();
}
