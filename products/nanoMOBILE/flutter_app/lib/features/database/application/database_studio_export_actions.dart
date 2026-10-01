// QUÉ: acciones de exportación que complementan al controlador de Data Studio.
// CÓMO: mixin reutiliza estado Riverpod y DatabaseReportCoordinator inyectado.
// POR QUÉ: separa documentos/errores de la sesión y mantiene archivos pequeños.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/data_models.dart';
import 'database_report_coordinator.dart';
import 'database_studio_state.dart';

mixin DatabaseStudioExportActions on StateNotifier<DatabaseStudioState> {
  DatabaseReportCoordinator get reports;

  Future<String?> exportDelimited({bool tsv = false}) =>
      _export((table) => reports.delimited(table, tsv: tsv));

  Future<String?> exportHtml({String? title}) => _export(
    (table) => reports.html(table, title: title, query: state.queryResult?.query),
  );

  Future<String?> exportPdf({String? title, String? notes}) => _export(
    (table) => reports.pdf(
      table,
      title: title,
      notes: notes,
      query: state.queryResult?.query,
      executionTimeMs: state.queryResult?.executionTimeMs,
    ),
  );

  Future<void> shareCurrentReport({String? title}) async {
    final table = state.activeDisplayTable;
    if (table != null && table.isNotEmpty) {
      await reports.share(table, title: title);
    }
  }

  Future<String?> _export(Future<String> Function(DataTable) operation) async {
    final table = state.activeDisplayTable;
    if (table == null) return null;
    try {
      final path = await operation(table);
      state = state.copyWith(statusMessage: 'Archivo real creado: $path', clearError: true);
      return path;
    } catch (error) {
      state = state.copyWith(errorMessage: 'Falló la exportación: $error');
      return null;
    }
  }
}
