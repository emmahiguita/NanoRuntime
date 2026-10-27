import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../database/application/tabular_import_service.dart';
import '../../../database/domain/data_models.dart';
import '../../../database/infrastructure/native_sqlite_gateway.dart';

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
    return const TabularImportService().fromFile(filePath);
  }

  /// Carga datos desde una hoja de cálculo pública o compartida de Google Sheets.
  static Future<DataTable> loadFromGoogleSheets({
    required String sheetUrl,
    String? tableName,
  }) async {
    final table = await const TabularImportService().fromPublicGoogleSheet(
      sheetUrl,
    );
    return tableName == null ? table : table.copyWith(name: tableName);
  }

  /// Carga datos desde un servicio REST empresarial que devuelve una lista JSON de productos.
  static Future<DataTable> loadFromRestApi({
    required String endpointUrl,
    String? authToken,
  }) async {
    final uri = Uri.parse(endpointUrl);
    if (!uri.hasAuthority || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException(
        'La API debe usar una URL HTTP o HTTPS válida.',
      );
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      if (authToken != null && authToken.trim().isNotEmpty)
        'Authorization': authToken.startsWith('Bearer ')
            ? authToken
            : 'Bearer $authToken',
    };

    // Cerrar el cliente también cancela el socket cuando vence la espera.
    final client = http.Client();
    late http.Response res;
    try {
      res = await client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'La API no respondió en 15 segundos. Revisa la conexión y vuelve a intentar.',
      );
    } finally {
      client.close();
    }
    if (res.statusCode != 200) {
      throw Exception('Error al consultar API REST (HTTP ${res.statusCode}).');
    }

    final dynamic decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List<dynamic> items = decoded is List
        ? decoded
        : (decoded is Map
              ? (decoded['data'] as List? ?? decoded['items'] as List? ?? [])
              : []);

    if (items.isEmpty) {
      return const DataTable(name: 'rest_api', columns: [], rows: []);
    }

    final maps = <Map<String, dynamic>>[
      for (final item in items)
        if (item is Map)
          {for (final entry in item.entries) entry.key.toString(): entry.value},
    ];
    if (maps.isEmpty) {
      throw const FormatException('La API no devolvió objetos de productos.');
    }
    final firstItem = maps.first;
    final columns = firstItem.keys.toList();
    final rows = <List<dynamic>>[];

    for (final item in maps) {
      rows.add([for (final col in columns) item[col]?.toString() ?? '']);
    }

    return DataTable(name: 'rest_api', columns: columns, rows: rows);
  }

  /// Carga datos desde una base de datos SQLite local de forma segura.
  static Future<DataTable> loadFromSqlite({
    required String dbPath,
    String tableName = 'products',
  }) async {
    final cleanTable = tableName.replaceAll(RegExp(r'[^\w_]'), '');
    if (cleanTable.isEmpty) {
      throw const FormatException('Selecciona una tabla SQLite válida.');
    }
    final query = 'SELECT * FROM "$cleanTable" LIMIT 1000;';
    final result = await const NativeSqliteGateway().execute(
      path: dbPath,
      query: query,
    );
    if (!result.isSuccess || result.table == null) {
      throw Exception(
        result.errorMessage ?? 'No se pudo leer la tabla $tableName',
      );
    }
    return result.table!;
  }
}
