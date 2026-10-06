// QUÉ: acciones de exportación que complementan al controlador de Data Studio.
// CÓMO: mixin reutiliza estado Riverpod y DatabaseReportCoordinator inyectado.
// POR QUÉ: separa documentos/errores de la sesión y mantiene archivos pequeños.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/data_models.dart';
import '../domain/report_section.dart';
import 'database_report_coordinator.dart';
import 'database_studio_state.dart';

mixin DatabaseStudioExportActions on StateNotifier<DatabaseStudioState> {
  DatabaseReportCoordinator get reports;

  Future<String?> exportDelimited({bool tsv = false}) =>
      _export((table) => reports.delimited(table, tsv: tsv));

  Future<String?> exportHtml({String? title}) => _export(
    (table) =>
        reports.html(table, title: title, query: state.queryResult?.query),
  );

  Future<String?> exportPdf({
    String? title,
    String? notes,
    List<ReportSection>? sections,
  }) => _export(
    (table) => reports.pdf(
      table,
      title: title,
      notes: notes,
      sections: sections,
      query: state.queryResult?.query,
      executionTimeMs: state.queryResult?.executionTimeMs,
    ),
  );

  // Comparte la misma composición elegida en el editor y reporta errores.
  Future<bool> shareCurrentReport({
    String? title,
    String? notes,
    List<ReportSection>? sections,
  }) async {
    final table = state.activeDisplayTable;
    if (table == null || table.isEmpty) return false;
    try {
      await reports.share(
        table,
        title: title,
        notes: notes,
        sections: sections,
        query: state.queryResult?.query,
        executionTimeMs: state.queryResult?.executionTimeMs,
      );
      return true;
    } catch (error) {
      state = state.copyWith(errorMessage: 'Falló la compartición: $error');
      return false;
    }
  }

  Future<String?> _export(Future<String> Function(DataTable) operation) async {
    final table = state.activeDisplayTable;
    if (table == null) return null;
    try {
      final path = await operation(table);
      state = state.copyWith(
        statusMessage: 'Archivo real creado: $path',
        clearError: true,
      );
      return path;
    } catch (error) {
      state = state.copyWith(errorMessage: 'Falló la exportación: $error');
      return null;
    }
  }
}
