// QUÉ: coordina conexiones, consultas, importaciones y exportaciones de Data Studio.
// CÓMO: elige SQLite nativo para bases reales y el motor local para tablas importadas.
// POR QUÉ: mantiene la UI separada de archivos, plataforma y generación de informes.

library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/database_port.dart';
import '../infrastructure/device_data_file_picker.dart';
import '../infrastructure/native_sqlite_gateway.dart';
import 'database_report_coordinator.dart';
import 'database_session_loader.dart';
import 'database_studio_export_actions.dart';
import 'database_studio_source_actions.dart';
import 'database_studio_state.dart';
import 'sql_query_engine.dart';
import 'tabular_import_service.dart';

export 'database_studio_state.dart';

final databaseStudioControllerProvider =
    StateNotifierProvider<DatabaseStudioController, DatabaseStudioState>(
      (ref) => DatabaseStudioController(),
    );

class DatabaseStudioController extends StateNotifier<DatabaseStudioState>
    with DatabaseStudioExportActions, DatabaseStudioSourceActions {
  @override
  final DatabasePort database;
  @override
  final TabularImportService importer;
  @override
  final DeviceDataFilePicker filePicker;
  @override
  final DatabaseSessionLoader sessionLoader;

  @override
  final DatabaseReportCoordinator reports;

  // Último trabajo gana: impide que respuestas antiguas sobrescriban la UI.
  int _queryRevision = 0;

  DatabaseStudioController({
    this.database = const NativeSqliteGateway(),
    this.importer = const TabularImportService(),
    this.filePicker = const DeviceDataFilePicker(),
    this.sessionLoader = const DatabaseSessionLoader(),
    this.reports = const DatabaseReportCoordinator(),
  }) : super(
         const DatabaseStudioState(
           tables: {},
           selectedTableName: '',
           // Query inicial: lista tablas del portafolio de servicios de programación.
           // Se reemplaza automáticamente al conectar la demo o una BD real.
           currentQuery: "SELECT * FROM servicios_programacion ORDER BY precio_cop DESC;",
           isShellConnected: false,
           statusMessage: 'Conectando SQLite local…',
         ),
       ) {
    unawaited(initializeDefaultDatabase());
  }

  void updateQueryText(String query) =>
      state = state.copyWith(currentQuery: query);

  void selectTable(String tableName) {
    if (!state.tables.containsKey(tableName)) return;
    final query = state.databasePath == null
        ? 'SELECT * FROM $tableName LIMIT 50;'
        : 'SELECT * FROM "${tableName.replaceAll('"', '""')}" LIMIT 50;';
    state = state.copyWith(
      selectedTableName: tableName,
      currentQuery: query,
      clearError: true,
    );
    unawaited(executeCurrentQuery());
  }

  @override
  Future<void> executeCurrentQuery() async {
    final query = state.currentQuery.trim();
    if (query.isEmpty) return;
    final revision = ++_queryRevision;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final path = state.databasePath;
      final result = path == null
          ? SqlQueryEngine.executeMemoryQuery(
              query: query,
              tables: state.tables,
            )
          : await database.execute(path: path, query: query);
      if (!mounted || revision != _queryRevision) return;
      final history = _remember(query, state.queryHistory);
      final count = result.affectedRows ?? result.rowCount;
      final resultKind = result.affectedRows == null
          ? 'devueltas'
          : 'afectadas';
      state = state.copyWith(
        isLoading: false,
        queryResult: result,
        queryHistory: history,
        errorMessage: result.errorMessage,
        clearError: result.isSuccess,
        statusMessage: result.isSuccess
            ? 'Consulta completada en ${result.executionTimeMs} ms · '
                  '$count filas $resultKind'
                  '${result.truncated ? ' · vista limitada a datos recibidos' : ''}'
            : 'La consulta no se completó',
      );
    } catch (error) {
      if (!mounted || revision != _queryRevision) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Fallo de ejecución: $error',
      );
    }
  }

  @override
  void invalidatePendingQuery() => _queryRevision++;

  static List<String> _remember(String query, List<String> previous) {
    final history = <String>[query, ...previous.where((item) => item != query)];
    return history.take(20).toList(growable: false);
  }
}
