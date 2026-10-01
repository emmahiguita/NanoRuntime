// QUÉ: coordina la apertura de SQLite, archivos y Google Sheets.
// CÓMO: usa una revisión creciente para aceptar solo la fuente más reciente.
// POR QUÉ: evita carreras con la conexión automática y mantiene el controlador pequeño.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/database_port.dart';
import '../infrastructure/device_data_file_picker.dart';
import 'database_session_loader.dart';
import 'database_studio_state.dart';
import 'tabular_import_service.dart';

mixin DatabaseStudioSourceActions on StateNotifier<DatabaseStudioState> {
  DatabasePort get database;
  TabularImportService get importer;
  DeviceDataFilePicker get filePicker;
  DatabaseSessionLoader get sessionLoader;
  Future<void> executeCurrentQuery();
  void invalidatePendingQuery();

  int _sourceRevision = 0;

  Future<void> initializeDefaultDatabase() async {
    const revision = 0;
    try {
      final localPath = await database.ensureDefaultDatabase();
      final hasLocalTables = (await database.listTables(localPath)).isNotEmpty;
      final path = hasLocalTables
          ? localPath
          : await database.ensureDemoDatabase();
      final message = hasLocalTables
          ? 'SQLite local conectada'
          : 'Ejemplo profesional SQLite';
      await _openDatabase(path, message, revision);
    } catch (error) {
      if (!_isCurrent(revision)) return;
      state = state.copyWith(
        isLoading: false,
        isShellConnected: false,
        errorMessage: 'SQLite no está disponible: $error',
      );
    }
  }

  Future<bool> importFileFromDevice() async {
    final path = await filePicker.pick();
    return path == null ? false : importFromShellPath(path);
  }

  Future<bool> openProfessionalDemo() async {
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

  Future<bool> importPublicGoogleSheet(String url) async {
    final revision = _begin();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final table = await importer.fromPublicGoogleSheet(url);
      if (!_isCurrent(revision)) return false;
      state = state.withImportedTable(table, 'Google Sheets conectado');
      await executeCurrentQuery();
      return true;
    } catch (error) {
      return _fail(revision, 'No se pudo importar Google Sheets: $error');
    }
  }

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
