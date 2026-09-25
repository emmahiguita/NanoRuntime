// database_studio_controller.dart
//
// QUÉ HACE:
// Controlador Riverpod del Estudio de Bases de Datos, SQL y Generación de Reportes.
//
// CÓMO FUNCIONA:
// - Inicializa con la base de datos empresarial real (`RealBusinessDatabaseFactory`).
// - Ejecuta consultas SQL en memoria o sobre SQLite en Shell con `SqlQueryEngine`.
// - Soporta importación de archivos, conexión de rutas Shell y exportación a PDF.
//
// POR QUÉ:
// Aplica Clean Architecture y SOLID manteniendo el archivo en < 180 líneas.

library;

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/data_models.dart';
import 'csv_tsv_parser.dart';
import 'database_studio_state.dart';
import 'real_business_database_factory.dart';
import 'report_generator_service.dart';
import 'sql_query_engine.dart';

export 'database_studio_state.dart';

final databaseStudioControllerProvider = StateNotifierProvider<DatabaseStudioController, DatabaseStudioState>((ref) {
  return DatabaseStudioController();
});

class DatabaseStudioController extends StateNotifier<DatabaseStudioState> {
  DatabaseStudioController() : super(const DatabaseStudioState(tables: {}, selectedTableName: '', currentQuery: 'SELECT * FROM productos LIMIT 25;')) {
    _loadInitialRealDatabase();
  }

  void _loadInitialRealDatabase() {
    final realTables = RealBusinessDatabaseFactory.createBusinessDataTables();
    const defaultQuery = 'SELECT * FROM productos LIMIT 25;';
    final initialResult = SqlQueryEngine.executeMemoryQuery(query: defaultQuery, tables: realTables);

    state = state.copyWith(
      tables: realTables,
      selectedTableName: 'productos',
      currentQuery: defaultQuery,
      queryResult: initialResult,
      queryHistory: [
        defaultQuery,
        'SELECT categoria, COUNT(*), SUM(precio * stock) FROM productos GROUP BY categoria;',
        'SELECT estado, COUNT(*), SUM(total) FROM pedidos GROUP BY estado;',
        'SELECT * FROM clientes WHERE total_compras > 1000000;',
        'SELECT canal, SUM(ingresos_totales) FROM metricas_ventas GROUP BY canal;',
      ],
      statusMessage: 'Base de datos comercial real cargada (5 tablas operativas).',
    );
  }

  void updateQueryText(String query) => state = state.copyWith(currentQuery: query);

  void selectTable(String tableName) {
    if (!state.tables.containsKey(tableName)) return;
    final newQuery = 'SELECT * FROM $tableName LIMIT 50;';
    final result = SqlQueryEngine.executeMemoryQuery(query: newQuery, tables: state.tables);
    state = state.copyWith(
      selectedTableName: tableName,
      currentQuery: newQuery,
      queryResult: result,
      statusMessage: 'Tabla activa: $tableName (${state.tables[tableName]!.rowCount} filas)',
    );
  }

  Future<void> executeCurrentQuery() async {
    final query = state.currentQuery.trim();
    if (query.isEmpty) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = SqlQueryEngine.executeMemoryQuery(query: query, tables: state.tables);
      final updatedHistory = List<String>.from(state.queryHistory);
      if (!updatedHistory.contains(query)) {
        updatedHistory.insert(0, query);
        if (updatedHistory.length > 20) updatedHistory.removeLast();
      }
      state = state.copyWith(
        isLoading: false,
        queryResult: result,
        queryHistory: updatedHistory,
        errorMessage: result.errorMessage,
        statusMessage: result.isSuccess ? 'Consulta completada en ${result.executionTimeMs}ms (${result.rowCount} filas)' : 'Error en consulta SQL',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Fallo de ejecución: $e');
    }
  }

  Future<bool> importFileFromDevice() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'tsv', 'txt', 'sql', 'sqlite', 'db']);
      if (result == null || result.files.isEmpty || result.files.first.path == null) return false;
      final file = result.files.first;
      final rawContent = await File(file.path!).readAsString();
      final tableName = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      final parsed = CsvTsvParser.parse(name: tableName, rawContent: rawContent);
      final updated = Map<String, DataTable>.from(state.tables)..[tableName] = parsed;
      state = state.copyWith(
        tables: updated,
        selectedTableName: tableName,
        currentQuery: 'SELECT * FROM $tableName LIMIT 50;',
        statusMessage: 'Hoja importada: $tableName (${parsed.rowCount} filas)',
      );
      await executeCurrentQuery();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error importando archivo: $e');
      return false;
    }
  }

  Future<bool> importFromShellPath(String shellFilePath) async {
    try {
      final file = File(shellFilePath);
      if (!await file.exists()) {
        state = state.copyWith(errorMessage: 'Archivo Shell no existe: $shellFilePath');
        return false;
      }
      final content = await file.readAsString();
      final name = file.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').toLowerCase();
      final table = CsvTsvParser.parse(name: name, rawContent: content);
      final updated = Map<String, DataTable>.from(state.tables)..[name] = table;
      state = state.copyWith(
        tables: updated,
        selectedTableName: name,
        currentQuery: 'SELECT * FROM $name LIMIT 50;',
        statusMessage: 'Conectado a Shell: $shellFilePath (${table.rowCount} filas)',
      );
      await executeCurrentQuery();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Fallo al leer hoja de shell: $e');
      return false;
    }
  }

  Future<void> generateAndPreviewPdfReport({String? title, String? notes}) async {
    final table = state.activeDisplayTable;
    if (table == null || table.isEmpty) {
      state = state.copyWith(errorMessage: 'No hay datos en la tabla para generar informe.');
      return;
    }
    try {
      final config = DataReportConfig(
        title: title ?? 'Informe de ${table.name.replaceAll("_", " ").toUpperCase()}',
        subtitle: 'Análisis de datos generado desde NanoAI Terminal Studio',
        queryUsed: state.queryResult?.query,
        notes: notes,
      );
      await ReportGeneratorService.previewOrPrintReport(table: table, config: config, executionTimeMs: state.queryResult?.executionTimeMs);
      state = state.copyWith(statusMessage: 'Informe PDF renderizado.');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error generando PDF: $e');
    }
  }

  Future<void> shareCurrentReport({String? title}) async {
    final table = state.activeDisplayTable;
    if (table == null || table.isEmpty) return;
    try {
      final config = DataReportConfig(title: title ?? 'Informe ${table.name}', queryUsed: state.queryResult?.query);
      await ReportGeneratorService.shareReport(table: table, config: config, executionTimeMs: state.queryResult?.executionTimeMs);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error compartiendo informe: $e');
    }
  }

  Future<String?> exportToShellDirectory({bool isTsv = false}) async {
    final table = state.activeDisplayTable;
    if (table == null) return null;
    try {
      final content = isTsv ? table.toTsv() : table.toCsv();
      final ext = isTsv ? 'tsv' : 'csv';
      final fileName = '${table.name}_export_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = await ReportGeneratorService.saveReportToDisk(table: table, config: DataReportConfig(title: fileName));
      await File(path).writeAsString(content);
      state = state.copyWith(statusMessage: 'Exportado en: $path');
      return path;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Fallo al exportar: $e');
      return null;
    }
  }
}
