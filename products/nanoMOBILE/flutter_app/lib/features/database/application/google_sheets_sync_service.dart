// google_sheets_sync_service.dart
//
// QUÉ HACE:
// Servicio para leer hojas públicas y sincronizar cambios mediante un Web App de Apps Script.
//
// CÓMO FUNCIONA:
// - Analiza URLs directas de Google Sheets (ID de hoja, gid, o panel general /spreadsheets/u/0/?pli=1).
// - Lee CSV públicos o JSON de un Web App de Apps Script.
// - Escribe cambios de celdas y permite que el controlador sondee cambios externos.
//
// POR QUÉ:
// Resuelve la necesidad del usuario de gestionar hojas de cálculo reales sin bases sintéticas no deseadas.

library;

import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import '../domain/data_models.dart';
import 'csv_tsv_parser.dart';

class GoogleSheetsSyncService {
  static const String defaultSheetsHomeUrl =
      'https://docs.google.com/spreadsheets/u/0/?pli=1';

  /// Hoja de cálculo oficial predeterminada en vivo con datos tabulares reales
  static const String defaultAutomatedSheetUrl =
      'https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit?usp=sharing';

  final http.Client? _customClient;

  const GoogleSheetsSyncService({http.Client? client})
      : _customClient = client;

  Future<http.Response> _get(Uri uri) async {
    final client = _customClient ?? http.Client();
    try {
      return await client.get(uri).timeout(const Duration(seconds: 20));
    } finally {
      if (_customClient == null) client.close();
    }
  }

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = _customClient ?? http.Client();
    try {
      return await client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    } finally {
      if (_customClient == null) client.close();
    }
  }

  bool isAppsScriptEndpoint(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'script.google.com' &&
        uri.path.contains('/macros/s/') &&
        uri.path.endsWith('/exec');
  }

  /// Extrae el ID del spreadsheet de cualquier URL de Google Docs/Sheets
  String? extractSpreadsheetId(String url) {
    final clean = url.trim();
    final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(clean);
    return match?.group(1);
  }

  /// Extrae el GID de la hoja específica si está presente
  String? extractGid(String url) {
    final clean = url.trim();
    final uri = Uri.tryParse(clean);
    if (uri == null) return null;
    final fragmentGid =
        RegExp(r'(?:^|&)gid=(\d+)').firstMatch(uri.fragment)?.group(1);
    return uri.queryParameters['gid'] ?? fragmentGid;
  }

  /// Valida si una URL es la raíz de Google Sheets
  bool isSheetsHomeUrl(String url) {
    final clean = url.trim();
    return clean.contains('/spreadsheets/u/') ||
        clean.endsWith('/spreadsheets') ||
        clean.contains('/spreadsheets/?') ||
        clean.contains('spreadsheets/u/0/?pli=1');
  }

  /// Genera la URL de colaboración directa en el navegador para la cuenta dada
  String getCollaborativeBrowserUrl(
      {String? spreadsheetId, String? email}) {
    if (spreadsheetId != null && spreadsheetId.isNotEmpty) {
      final authUser = email == null || email.trim().isEmpty
          ? ''
          : '&authuser=${Uri.encodeComponent(email.trim())}';
      return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit?usp=sharing$authUser';
    }
    return defaultAutomatedSheetUrl;
  }

  /// Descarga y parsea una hoja de Google Sheets.
  Future<DataTable> fetchSheet({
    required String url,
    String? syncEndpointUrl,
    String? customTableName,
  }) async {
    final effectiveUrl = isSheetsHomeUrl(url) ? defaultAutomatedSheetUrl : url.trim();
    final sheetId = extractSpreadsheetId(effectiveUrl);
    if (sheetId == null) {
      throw const FormatException(
        'El enlace no contiene un ID de Google Sheets válido (/spreadsheets/d/...).',
      );
    }

    final tableName =
        customTableName ?? 'google_sheet_${sheetId.substring(0, 8)}';
    final endpoint = syncEndpointUrl?.trim();
    if (endpoint != null && endpoint.isNotEmpty) {
      if (!isAppsScriptEndpoint(endpoint)) {
        throw const FormatException(
          'El endpoint debe ser la URL /exec de un Web App de Google Apps Script.',
        );
      }
      return _fetchFromAppsScript(
        sheetUrl: url,
        sheetId: sheetId,
        endpointUrl: endpoint,
        tableName: tableName,
      );
    }

    return _fetchPublicCsv(
      url: url,
      sheetId: sheetId,
      tableName: tableName,
    );
  }

  Future<DataTable> _fetchPublicCsv({
    required String url,
    required String sheetId,
    required String tableName,
  }) async {
    final gid = extractGid(url);
    final exportUri = Uri.https(
      'docs.google.com',
      '/spreadsheets/d/$sheetId/export',
      {'format': 'csv', if (gid != null) 'gid': gid},
    );

    final response = await _get(exportUri);
    if (response.statusCode != 200) {
      throw StateError(
        'Google Sheets respondió HTTP ${response.statusCode}. '
        'Para importar sin iniciar sesión, publica la hoja para lectura o configura el Web App de Apps Script.',
      );
    }

    final content = utf8.decode(response.bodyBytes);
    if (content.trimLeft().startsWith('<')) {
      throw StateError(
        'Google Sheets no entregó un CSV público. Configura un Web App de Apps Script para acceder a una hoja privada.',
      );
    }

    final table = await Isolate.run(
      () => CsvTsvParser.parse(
        name: tableName,
        rawContent: content,
        explicitDelimiter: ',',
      ),
    );

    return table.copyWith(sourceUrl: url);
  }

  Future<DataTable> _fetchFromAppsScript({
    required String sheetUrl,
    required String sheetId,
    required String endpointUrl,
    required String tableName,
  }) async {
    final endpoint = _endpointUri(endpointUrl, sheetUrl: sheetUrl);
    final response = await _get(endpoint);
    if (response.statusCode != 200) {
      throw StateError(
        'El Web App de Apps Script respondió HTTP ${response.statusCode}. Revisa su implementación y permisos de acceso.',
      );
    }

    final content = utf8.decode(response.bodyBytes);
    if (content.trimLeft().startsWith('<')) {
      throw StateError(
        'Apps Script devolvió una página de acceso. Despliega el Web App con permisos para que NanoAI pueda leerlo.',
      );
    }
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic> &&
        decoded['spreadsheetId'] != null &&
        decoded['spreadsheetId'] != sheetId) {
      // StateError no tiene constructor const; se lanza al detectar una hoja distinta.
      throw StateError(
        'El Web App pertenece a otra hoja de cálculo. Usa el endpoint vinculado a esta hoja.',
      );
    }
    final rawRows = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['values'] ?? decoded['data']
        : null;
    if (rawRows is! List || rawRows.isEmpty || rawRows.first is! List) {
      throw const FormatException(
        'El Web App debe devolver una matriz JSON con los encabezados en la primera fila.',
      );
    }

    final header = rawRows.first as List;
    final columns = header.map((value) => value?.toString() ?? '').toList();
    if (columns.isEmpty || columns.every((column) => column.trim().isEmpty)) {
      throw const FormatException('La hoja no tiene encabezados para importar.');
    }

    final rows = <List<dynamic>>[];
    for (final candidate in rawRows.skip(1)) {
      if (candidate is! List) continue;
      rows.add(
        List<dynamic>.generate(
          columns.length,
          (index) => index < candidate.length ? candidate[index] : null,
          growable: false,
        ),
      );
    }

    return DataTable(
      name: tableName,
      columns: columns,
      rows: rows,
      sourceUrl: sheetUrl,
      syncEndpointUrl: endpointUrl,
    );
  }

  /// Actualiza una celda en tiempo real en Google Sheets si se cuenta con Apps Script Webhook
  Future<bool> pushCellUpdate({
    required String syncEndpointUrl,
    required String sheetUrl,
    required int rowIndex,
    required int columnIndex,
    required dynamic value,
    required String columnName,
  }) async {
    final endpoint = syncEndpointUrl.trim();
    if (!isAppsScriptEndpoint(endpoint)) return false;

    try {
      final response = await _post(
        _endpointUri(endpoint, sheetUrl: sheetUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'updateCell',
          'spreadsheetId': extractSpreadsheetId(sheetUrl),
          'row': rowIndex,
          'col': columnIndex,
          'columnName': columnName,
          'value': value,
          'gid': extractGid(sheetUrl),
        }),
      );
      if (response.statusCode != 200) return false;

      final result = jsonDecode(utf8.decode(response.bodyBytes));
      if (result is Map<String, dynamic> && result.containsKey('status')) {
        return result['status'] == 'ok';
      }

      // Apps Script may redirect ContentService responses; verify the value
      // through the read endpoint instead of treating any HTTP 200 as success.
      final current = await fetchSheet(
        url: sheetUrl,
        syncEndpointUrl: endpoint,
      );
      return rowIndex < current.rows.length &&
          columnIndex < current.columns.length &&
          _sameValue(current.rows[rowIndex][columnIndex], value);
    } catch (_) {
      return false;
    }
  }

  Uri _endpointUri(String endpointUrl, {required String sheetUrl}) {
    final uri = Uri.parse(endpointUrl.trim());
    final gid = extractGid(sheetUrl);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        if (gid != null) 'gid': gid,
      },
    );
  }

  bool _sameValue(dynamic left, dynamic right) =>
      left == right || left?.toString() == right?.toString();

  /// Puente de Apps Script para lectura periódica y edición bidireccional.
  static String get appsScriptTemplate => '''
function sheetFor_(gid) {
  var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  if (gid) {
    var requestedId = Number(gid);
    var requestedSheet = spreadsheet.getSheets().find(function(sheet) {
      return sheet.getSheetId() === requestedId;
    });
    if (requestedSheet) return requestedSheet;
  }
  return spreadsheet.getActiveSheet();
}

function doGet(e) {
  var gid = e && e.parameter ? e.parameter.gid : null;
  var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = sheetFor_(gid);
  return ContentService.createTextOutput(JSON.stringify({
    spreadsheetId: spreadsheet.getId(),
    values: sheet.getDataRange().getValues()
  }))
    .setMimeType(ContentService.MimeType.JSON);
}
function doPost(e) {
  var params = JSON.parse(e.postData.contents);
  var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  if (params.spreadsheetId && params.spreadsheetId !== spreadsheet.getId()) {
    return ContentService.createTextOutput(JSON.stringify({status: "error", message: "ID de hoja incorrecto"})).setMimeType(ContentService.MimeType.JSON);
  }
  var sheet = sheetFor_(params.gid);
  if (params.action === "updateCell") {
    sheet.getRange(Number(params.row) + 2, Number(params.col) + 1).setValue(params.value);
    return ContentService.createTextOutput(JSON.stringify({status: "ok", row: params.row, col: params.col})).setMimeType(ContentService.MimeType.JSON);
  }
  return ContentService.createTextOutput(JSON.stringify({status: "error", message: "Acción no reconocida"})).setMimeType(ContentService.MimeType.JSON);
}''';
}
