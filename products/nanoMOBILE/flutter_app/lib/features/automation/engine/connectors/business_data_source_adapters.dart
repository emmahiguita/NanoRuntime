import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../database/application/csv_tsv_parser.dart';
import '../../../database/application/sql_query_engine.dart';
import '../../../database/domain/data_models.dart';
import 'excel_data_decoder.dart';

// business_data_source_adapters.dart
//
// QUÉ HACE:
// Adapta diversas fuentes de datos (Excel, CSV, Google Sheets, SQLite y REST)
// a la estructura homogénea DataTable requerida para la normalización comercial.
//
// CÓMO FUNCIONA:
// - CsvDataSource: Lee archivos locales y reutiliza CsvTsvParser con detección de delimitador.
// - ExcelDataSource: Decodifica bytes de hojas .xlsx vía ExcelDataDecoder.
// - GoogleSheetsDataSource: Transforma enlaces de Google Sheets en endpoints de exportación CSV.
// - RemoteRestDataSource: Consume APIs empresariales autenticadas y mapea JSON a DataTable.
//
// POR QUÉ:
// Aplica el patrón Adapter y Segregación de Interfaces (ISP), evitando acoplamientos
// con protocolos específicos en la capa de negocio.

class BusinessDataSourceAdapters {
  /// Carga datos desde un archivo local según su extensión (.xlsx, .csv, .tsv).
  static Future<DataTable> loadFromFile({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.xlsx')) {
      return ExcelDataDecoder.decodeXlsx(bytes: bytes, tableName: fileName);
    } else {
      // Intentar UTF-8 con fallback a Latin1
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      return CsvTsvParser.parse(name: fileName, rawContent: text);
    }
  }

  /// Carga datos desde una hoja de cálculo pública o compartida de Google Sheets.
  static Future<DataTable> loadFromGoogleSheets({
    required String sheetUrl,
    String? tableName,
  }) async {
    final cleanUrl = _buildGoogleSheetsExportUrl(sheetUrl);
    final response = await http.get(Uri.parse(cleanUrl)).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Fallo al conectar con Google Sheets (HTTP ${response.statusCode}).');
    }

    final csvText = utf8.decode(response.bodyBytes);
    return CsvTsvParser.parse(
      name: tableName ?? 'Google Sheets',
      rawContent: csvText,
      explicitDelimiter: ',',
    );
  }

  /// Carga datos desde un servicio REST empresarial que devuelve una lista JSON de productos.
  static Future<DataTable> loadFromRestApi({
    required String endpointUrl,
    String? authToken,
  }) async {
    final uri = Uri.parse(endpointUrl);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (authToken != null && authToken.trim().isNotEmpty)
        'Authorization': authToken.startsWith('Bearer ') ? authToken : 'Bearer $authToken',
    };

    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Error al consultar API REST (HTTP ${res.statusCode}).');
    }

    final dynamic decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List<dynamic> items = decoded is List ? decoded : (decoded is Map ? (decoded['data'] as List? ?? decoded['items'] as List? ?? []) : []);

    if (items.isEmpty) {
      return const DataTable(name: 'rest_api', columns: [], rows: []);
    }

    final firstItem = items.first as Map<String, dynamic>;
    final columns = firstItem.keys.toList();
    final rows = <List<dynamic>>[];

    for (final item in items) {
      if (item is Map) {
        rows.add([for (final col in columns) item[col]?.toString() ?? '']);
      }
    }

    return DataTable(name: 'rest_api', columns: columns, rows: rows);
  }

  /// Carga datos desde una base de datos SQLite local de forma segura.
  static Future<DataTable> loadFromSqlite({
    required String dbPath,
    String tableName = 'products',
  }) async {
    final cleanTable = tableName.replaceAll(RegExp(r'[^\w_]'), '');
    final query = 'SELECT * FROM $cleanTable LIMIT 1000;';
    final result = await SqlQueryEngine.executeShellSqliteQuery(dbPath: dbPath, query: query);
    if (!result.isSuccess || result.table == null) {
      throw Exception(result.errorMessage ?? 'No se pudo leer la tabla $tableName');
    }
    return result.table!;
  }

  static String _buildGoogleSheetsExportUrl(String rawUrl) {
    if (rawUrl.contains('export?format=csv')) return rawUrl;
    final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(rawUrl);
    if (match != null) {
      final docId = match.group(1);
      return 'https://docs.google.com/spreadsheets/d/$docId/export?format=csv';
    }
    return rawUrl;
  }
}
