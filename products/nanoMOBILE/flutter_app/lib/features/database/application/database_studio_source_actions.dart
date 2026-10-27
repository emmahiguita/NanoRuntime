// QUÉ: coordina la apertura de SQLite, archivos y Google Sheets.
// CÓMO: usa una revisión creciente para aceptar solo la fuente más reciente.
// POR QUÉ: evita carreras con la conexión automática y mantiene el controlador pequeño.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/data_models.dart';
import '../domain/database_port.dart';
import '../infrastructure/device_data_file_picker.dart';
import 'database_session_loader.dart';
import 'database_studio_state.dart';
import 'google_sheets_sync_service.dart';
import 'tabular_import_service.dart';

mixin DatabaseStudioSourceActions on StateNotifier<DatabaseStudioState> {
  static const _savedSheetUrlKey = 'database_studio_google_sheet_url';
  static const _savedSheetEndpointKey = 'database_studio_google_sheet_endpoint';
  static const _sheetSyncInterval = Duration(seconds: 10);

  DatabasePort get database;
  TabularImportService get importer;
  DeviceDataFilePicker get filePicker;
  DatabaseSessionLoader get sessionLoader;
  GoogleSheetsSyncService get sheetsSync;
  Future<void> executeCurrentQuery();
  void invalidatePendingQuery();

  int _sourceRevision = 0;
  int _sheetPreferenceRevision = 0;
  Timer? _googleSheetsSyncTimer;
  bool _googleSheetsRefreshInProgress = false;
  bool _googleSheetsWriteInProgress = false;

  /// QUÉ: Inicializa el almacenamiento por defecto y restaura o auto-conecta Google Sheets.
  /// CÓMO: Usa _begin() y _isCurrent(revision) para cancelar el flujo si el usuario cambia de fuente
  ///        o limpia la sesión durante la carga asíncrona (previene carreras y procesos zombi).
  /// POR QUÉ: Garantiza un inicio consistente y automatizado sin datos residuales.
  Future<void> initializeDefaultDatabase() async {
    final revision = _begin();
    try {
      final localPath = await database.ensureDefaultDatabase();
      if (!_isCurrent(revision)) return;
      final hasLocalTables = (await database.listTables(localPath)).isNotEmpty;
      if (!_isCurrent(revision)) return;
      if (hasLocalTables) {
        await _openDatabase(localPath, 'SQLite local conectada', revision);
      } else {
        state = state.copyWith(
          isLoading: false,
          isShellConnected: false,
          databasePath: localPath,
          statusMessage: 'Base de datos lista · Conecta Google Sheets o crea tablas',
        );
      }
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = state.copyWith(
        isLoading: false,
        isShellConnected: false,
        errorMessage: 'SQLite no está disponible: ',
      );
    }
    if (!_isCurrent(revision)) return;
    final restored = await _restoreGoogleSheetsConnection();
    if (!_isCurrent(revision)) return;
    if (!restored && state.tables.isEmpty) {
      unawaited(autoConnectGoogleSheets());
    }
  }

  /// Conecta automáticamente una hoja de cálculo con sincronización en tiempo real.
  Future<bool> autoConnectGoogleSheets({
    String? sheetUrl,
    String? syncEndpointUrl,
  }) async {
    final targetUrl = (sheetUrl != null && sheetUrl.trim().isNotEmpty)
        ? sheetUrl.trim()
        : GoogleSheetsSyncService.defaultAutomatedSheetUrl;
    return connectRealtimeGoogleSheet(
      targetUrl,
      syncEndpointUrl: syncEndpointUrl,
      persistConnection: true,
    );
  }

  /// Limpia la sesión actual y deja un espacio de trabajo en blanco
  /// respondiendo a la necesidad de no tener datos sintéticos forzados.
  void clearToBlankDatabase() {
    _forgetGoogleSheetsConnection();
    _sourceRevision++;
    invalidatePendingQuery();
    state = const DatabaseStudioState(
      tables: {},
      selectedTableName: '',
      currentQuery: '',
      isShellConnected: false,
      statusMessage: 'Espacio en blanco · Listo para Google Sheets o nueva tabla',
    );
  }

  Future<bool> importFileFromDevice() async {
    final path = await filePicker.pick();
    return path == null ? false : importFromShellPath(path);
  }

  Future<bool> openProfessionalDemo() async {
    await _removeSavedGoogleSheetsConnection();
    final revision = _begin();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final path = await database.ensureDemoDatabase();
      return _openDatabase(path, 'Ejemplo profesional SQLite', revision);
    } catch (error) {
      return _fail(revision, 'No se pudo abrir el ejemplo: $error');
    }
  }

  Future<bool> importFromShellPath(String path) async {
    await _removeSavedGoogleSheetsConnection();
    final revision = _begin();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (_isSqlite(path)) {
        return _openDatabase(path, 'SQLite conectada', revision);
      }
      final table = await importer.fromFile(path);
      if (!_isCurrent(revision)) return false;
      state = state.withImportedTable(table, 'Archivo conectado');
      await executeCurrentQuery();
      return true;
    } catch (error) {
      return _fail(revision, 'No se pudo conectar la fuente: $error');
    }
  }

  Future<bool> importPublicGoogleSheet(String url) async =>
      connectRealtimeGoogleSheet(url);

  /// Conecta una hoja y restaura su URL al iniciar la app.
  /// Un endpoint de Apps Script habilita escritura y lectura periódica.
  /// QUÉ: Conecta una hoja de Google Sheets y activa sincronización continua en tiempo real.
  /// CÓMO: Descarga la estructura tabular inicial, guarda la preferencia en SharedPreferences
  ///        y arranca el temporizador periódico para recibir actualizaciones vivas cada 10 segundos.
  /// POR QUÉ: Permite al usuario colaborar en Google Sheets desde móvil o PC y ver los cambios
  ///          reflejados automáticamente sin intervención manual.
  Future<bool> connectRealtimeGoogleSheet(
    String url, {
    String? syncEndpointUrl,
    bool persistConnection = true,
  }) async {
    _stopGoogleSheetsSyncTimer();
    final revision = _begin();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final endpoint = syncEndpointUrl?.trim();
      final table = await sheetsSync.fetchSheet(
        url: url,
        syncEndpointUrl: endpoint == null || endpoint.isEmpty ? null : endpoint,
      );
      if (!_isCurrent(revision)) return false;
      final syncMessage = table.syncEndpointUrl == null
          ? 'Google Sheets conectado · sincronización continua en tiempo real'
          : 'Google Sheets conectado · sincronización bidireccional activa';
      state = state.withImportedTable(
        table,
        syncMessage,
        isLiveSync: true,
      );
      var saved = true;
      if (persistConnection) {
        try {
          await _saveGoogleSheetsConnection(
            url,
            table.syncEndpointUrl,
            revision,
          );
        } catch (_) {
          saved = false;
        }
      }
      if (!_isCurrent(revision)) return false;
      _startGoogleSheetsSync(table);
      await executeCurrentQuery();
      if (mounted) {
        state = state.copyWith(
          isLiveSyncActive: true,
          lastSyncedAt: DateTime.now(),
          statusMessage: saved
              ? 'Sincronización en tiempo real activa · cada  s'
              : 'Sincronización activa · no se pudo guardar la reconexión automática',
        );
      }
      return true;
    } catch (error) {
      return _fail(revision, '');
    }
  }

  /// QUÉ: Fuerza una sincronización inmediata bajo demanda con Google Sheets.
  /// CÓMO: Invoca _refreshGoogleSheets ignorando el temporizador sin esperar al próximo tick.
  /// POR QUÉ: Facilita comprobación manual instantánea si el usuario acaba de editar celdas en Sheets.
  Future<void> syncGoogleSheetsNow() async {
    final current = state.currentTable;
    if (current == null || !current.isGoogleSheet || current.sourceUrl == null) {
      return;
    }
    await _refreshGoogleSheets(
      current.sourceUrl!,
      current.syncEndpointUrl,
      current.name,
    );
  }

  /// Actualiza una celda en memoria y despacha mutación a Google Sheets si está enlazada
  Future<void> updateTableCell({
    required int rowIndex,
    required int columnIndex,
    required dynamic value,
  }) async {
    final displayedTable = state.activeDisplayTable;
    if (displayedTable == null ||
        rowIndex < 0 ||
        rowIndex >= displayedTable.rows.length ||
        columnIndex < 0 ||
        columnIndex >= displayedTable.columns.length) {
      return;
    }

    final selectedSource = state.tables[state.selectedTableName];
    final isSheetResult = state.databasePath == null &&
        selectedSource?.isGoogleSheet == true &&
        (displayedTable.isGoogleSheet ||
            displayedTable.name == 'result_${selectedSource!.name}');
    if (!isSheetResult) {
      final updated = displayedTable.updateCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        newValue: value,
      );
      final tables = Map<String, DataTable>.from(state.tables)
        ..[updated.name] = updated;
      state = state.copyWith(
        tables: tables,
        statusMessage:
            'Celda actualizada [Fila ${rowIndex + 1}, ${displayedTable.columns[columnIndex]}]',
      );
      return;
    }

    final source = selectedSource!;
    final sourceColumn = source.columns.indexOf(displayedTable.columns[columnIndex]);
    final sourceRow = _resolveSourceRow(source, displayedTable, rowIndex);
    if (sourceColumn < 0 || sourceRow < 0) {
      state = state.copyWith(
        statusMessage: 'No se pudo ubicar esa celda en la hoja original',
      );
      return;
    }

    final updated = source.updateCell(
      rowIndex: sourceRow,
      columnIndex: sourceColumn,
      newValue: value,
    );
    final tables = Map<String, DataTable>.from(state.tables)
      ..[source.name] = updated;
    state = state.copyWith(tables: tables, clearQueryResult: true);
    await executeCurrentQuery();
    if (!mounted) return;

    final endpoint = updated.syncEndpointUrl;
    if (endpoint == null || endpoint.isEmpty) {
      state = state.copyWith(
        statusMessage:
            'Cambio local · configura un Web App de Apps Script para escribir en Google Sheets',
      );
      return;
    }

    _googleSheetsWriteInProgress = true;
    late final bool pushed;
    try {
      pushed = await sheetsSync.pushCellUpdate(
        syncEndpointUrl: endpoint,
        sheetUrl: updated.sourceUrl!,
        rowIndex: sourceRow,
        columnIndex: sourceColumn,
        columnName: source.columns[sourceColumn],
        value: value,
      );
    } finally {
      _googleSheetsWriteInProgress = false;
    }
    if (!mounted) return;
    state = state.copyWith(
      statusMessage: pushed
          ? 'Cambio guardado en Google Sheets'
          : 'No se pudo sincronizar · el cambio permanece solo en esta sesión',
    );
  }

  int _resolveSourceRow(
    DataTable source,
    DataTable displayed,
    int displayedRowIndex,
  ) {
    final displayedRow = displayed.rows[displayedRowIndex];
    final sourceColumns = displayed.columns
        .map(source.columns.indexOf)
        .toList(growable: false);
    if (sourceColumns.any((index) => index < 0)) return -1;

    final candidates = <int>[];
    for (var rowIndex = 0; rowIndex < source.rows.length; rowIndex++) {
      final sourceRow = source.rows[rowIndex];
      final matches = sourceColumns.asMap().entries.every((entry) {
        final sourceColumn = entry.value;
        return sourceColumn < sourceRow.length &&
            sourceRow[sourceColumn] == displayedRow[entry.key];
      });
      if (matches) candidates.add(rowIndex);
    }

    if (candidates.length == 1) return candidates.single;
    if (candidates.contains(displayedRowIndex)) return displayedRowIndex;
    return -1;
  }

  /// QUÉ: Restaura la última conexión persistida a Google Sheets al abrir la aplicación.
  /// CÓMO: Lee SharedPreferences; si existe URL guardada, la conecta y devuelve verdadero.
  /// POR QUÉ: Permite persistencia de sesión sin obligar al usuario a reintroducir la URL cada vez.
  Future<bool> _restoreGoogleSheetsConnection() async {
    try {
      final sourceRevision = _sourceRevision;
      final preferences = await SharedPreferences.getInstance();
      final url = preferences.getString(_savedSheetUrlKey);
      if (!mounted ||
          sourceRevision != _sourceRevision ||
          url == null ||
          url.isEmpty) {
        return false;
      }
      final endpoint = preferences.getString(_savedSheetEndpointKey);
      return await connectRealtimeGoogleSheet(
        url,
        syncEndpointUrl: endpoint,
        persistConnection: false,
      );
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        statusMessage: 'No se pudo restaurar la conexión guardada a Google Sheets',
      );
      return false;
    }
  }

  /// QUÉ: Persiste los parámetros de conexión de Google Sheets en almacenamiento local.
  /// CÓMO: Escribe en SharedPreferences protegiendo contra carreras con _sheetPreferenceRevision.
  /// POR QUÉ: Garantiza que reconexiones asíncronas no sobrescriban cambios de fuente más recientes.
  Future<void> _saveGoogleSheetsConnection(
    String url,
    String? endpoint,
    int revision,
  ) async {
    final preferenceRevision = ++_sheetPreferenceRevision;
    final preferences = await SharedPreferences.getInstance();
    if (!_isCurrent(revision) || preferenceRevision != _sheetPreferenceRevision) {
      return;
    }
    await preferences.setString(_savedSheetUrlKey, url.trim());
    if (endpoint == null || endpoint.isEmpty) {
      await preferences.remove(_savedSheetEndpointKey);
    } else {
      await preferences.setString(_savedSheetEndpointKey, endpoint);
    }
  }

  /// QUÉ: Elimina la preferencia guardada de Google Sheets.
  /// CÓMO: Cancela el timer de sincronización y borra las llaves de SharedPreferences.
  /// POR QUÉ: Usado al abrir SQLite o archivos locales para evitar reconectar Sheets indebidamente.
  Future<void> _removeSavedGoogleSheetsConnection() async {
    final preferenceRevision = ++_sheetPreferenceRevision;
    _stopGoogleSheetsSyncTimer();
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferenceRevision != _sheetPreferenceRevision) return;
      await preferences.remove(_savedSheetUrlKey);
      await preferences.remove(_savedSheetEndpointKey);
    } catch (_) {
      // SharedPreferences inaccesible no debe romper la experiencia local.
    }
  }

  void _forgetGoogleSheetsConnection() {
    _stopGoogleSheetsSyncTimer();
    unawaited(_removeSavedGoogleSheetsConnection());
  }

  /// QUÉ: Inicia el ciclo de sincronización en tiempo real para la tabla de Google Sheets.
  /// CÓMO: Limpia temporizadores previos e instancia un Timer.periodic cada 10s llamando a _refreshGoogleSheets.
  /// POR QUÉ: Asegura actualización en vivo tanto para hojas públicas directas como para endpoints Apps Script.
  void _startGoogleSheetsSync(DataTable table) {
    _stopGoogleSheetsSyncTimer();
    final url = table.sourceUrl;
    if (url == null || url.isEmpty) return;

    if (mounted) {
      state = state.copyWith(
        isLiveSyncActive: true,
        lastSyncedAt: DateTime.now(),
      );
    }

    _googleSheetsSyncTimer = Timer.periodic(
      _sheetSyncInterval,
      (_) => unawaited(_refreshGoogleSheets(url, table.syncEndpointUrl, table.name)),
    );
  }

  /// QUÉ: Sondea la hoja remota y detecta si hubo cambios reales en las celdas.
  /// CÓMO: Descarga los datos frescos de la hoja; si difieren de la versión en memoria,
  ///        actualiza el estado de las tablas y vuelve a ejecutar la consulta SQL activa.
  /// POR QUÉ: Proporciona la sincronización a tiempo real requerida sin crear procesos zombi ni recargas innecesarias.
  Future<void> _refreshGoogleSheets(
    String url,
    String? endpoint,
    String tableName,
  ) async {
    if (!mounted ||
        _googleSheetsRefreshInProgress ||
        _googleSheetsWriteInProgress ||
        state.isLoading) {
      return;
    }
    final existing = state.tables[tableName];
    if (existing?.sourceUrl != url || existing?.syncEndpointUrl != endpoint) {
      _stopGoogleSheetsSyncTimer();
      return;
    }

    _googleSheetsRefreshInProgress = true;
    try {
      final fresh = await sheetsSync.fetchSheet(
        url: url,
        syncEndpointUrl: endpoint,
        customTableName: tableName,
      );
      if (!mounted || !_isCurrentTable(url, endpoint, tableName)) return;
      final current = state.tables[tableName];
      if (current == null) return;

      final now = DateTime.now();
      if (_sameTableData(current, fresh)) {
        state = state.copyWith(lastSyncedAt: now);
        return;
      }

      final tables = Map<String, DataTable>.from(state.tables)
        ..[tableName] = fresh;
      state = state.copyWith(
        tables: tables,
        clearError: true,
        isLiveSyncActive: true,
        lastSyncedAt: now,
      );
      await executeCurrentQuery();
      if (mounted) {
        state = state.copyWith(
          statusMessage:
              'Sincronizado en tiempo real con Google Sheets (::) ·  filas',
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          statusMessage: 'Reintentando sincronización con Google Sheets...',
        );
      }
    } finally {
      _googleSheetsRefreshInProgress = false;
    }
  }

  bool _isCurrentTable(String url, String? endpoint, String tableName) {
    final table = state.tables[tableName];
    return table?.sourceUrl == url && table?.syncEndpointUrl == endpoint;
  }

  bool _sameTableData(DataTable left, DataTable right) {
    if (left.columns.length != right.columns.length ||
        left.rows.length != right.rows.length) {
      return false;
    }
    for (var column = 0; column < left.columns.length; column++) {
      if (left.columns[column] != right.columns[column]) return false;
    }
    for (var row = 0; row < left.rows.length; row++) {
      if (left.rows[row].length != right.rows[row].length) return false;
      for (var column = 0; column < left.rows[row].length; column++) {
        if (left.rows[row][column] != right.rows[row][column]) return false;
      }
    }
    return true;
  }

  /// QUÉ: Cancela el temporizador activo y previene fugas de recursos y procesos zombi.
  /// CÓMO: Invoca cancel() sobre el Timer periódico de Dart y desactiva isLiveSyncActive.
  /// POR QUÉ: Crucial en el ciclo de vida para respetar la liberación de recursos (Dispose/SRP).
  void _stopGoogleSheetsSyncTimer() {
    _googleSheetsSyncTimer?.cancel();
    _googleSheetsSyncTimer = null;
    if (mounted && state.isLiveSyncActive) {
      state = state.copyWith(isLiveSyncActive: false);
    }
  }

  void disposeGoogleSheetsSync() => _stopGoogleSheetsSyncTimer();

  Future<bool> _openDatabase(String path, String message, int revision) async {
    final snapshot = await sessionLoader.load(database, path);
    if (!_isCurrent(revision)) return false;
    state = state.copyWith(
      tables: snapshot.tables,
      selectedTableName: snapshot.selectedTable,
      currentQuery: snapshot.query,
      databasePath: snapshot.path,
      isShellConnected: true,
      isLoading: false,
      clearQueryResult: true,
      clearError: true,
      statusMessage: '$message · ${snapshot.tables.length} tablas',
    );
    await executeCurrentQuery();
    return true;
  }

  int _begin() {
    invalidatePendingQuery();
    return ++_sourceRevision;
  }

  bool _fail(int revision, String message) {
    if (!_isCurrent(revision)) return false;
    state = state.copyWith(isLoading: false, errorMessage: message);
    return false;
  }

  bool _isCurrent(int revision) => mounted && revision == _sourceRevision;

  static bool _isSqlite(String path) =>
      RegExp(r'\.(?:db|sqlite|sqlite3)$', caseSensitive: false).hasMatch(path);
}
