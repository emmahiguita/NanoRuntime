// database_studio_landscape_view.dart
//
// QUÉ HACE:
// Vista horizontal (Landscape) adaptada para el Estudio de Base de Datos y SQL.
//
// CÓMO FUNCIONA:
// - Divide la pantalla en dos paneles horizontales (Row):
//   - Panel Izquierdo (340dp): Selector compacto de tablas, consola SQL completa y barra de estado.
//   - Panel Derecho (Expanded): Cuadrícula de datos a pantalla completa con navegación bidireccional fluida.
// - Aplica tipografía mobile profesional (Inter y JetBrainsMono) con componentes pequeños y accesibles.
//
// POR QUÉ:
// Resuelve el cuello de botella visual donde la consola vertical colapsaba en pantallas horizontales (< 120 líneas).

library;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import '../widgets/database_data_grid.dart';
import '../widgets/database_sql_console.dart';
import '../widgets/database_status_banner.dart';
import '../widgets/database_table_selector.dart';

class DatabaseStudioLandscapeView extends StatelessWidget {
  final DatabaseStudioState state;
  final DatabaseStudioController controller;
  final TextEditingController queryController;
  final NanoColors colors;

  const DatabaseStudioLandscapeView({
    super.key,
    required this.state,
    required this.controller,
    required this.queryController,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Panel Izquierdo: Consola SQL y Selector de Tablas (Compacto)
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                right: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
            ),
            child: Column(
              children: [
                DatabaseTableSelector(
                  state: state,
                  controller: controller,
                  colors: colors,
                  onTableSelected: (tableName) {
                    queryController.text = 'SELECT * FROM $tableName LIMIT 50;';
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DatabaseSqlConsole(
                          queryController: queryController,
                          state: state,
                          controller: controller,
                          colors: colors,
                        ),
                        DatabaseStatusBanner(
                          errorMessage: state.errorMessage,
                          statusMessage: state.statusMessage,
                          latencyMs: state.queryResult?.executionTimeMs,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Panel Derecho: Cuadrícula de Datos Completa
        Expanded(
          child: Container(
            color: colors.background,
            child: DatabaseDataGrid(
              table: state.activeDisplayTable,
              colors: colors,
            ),
          ),
        ),
      ],
    );
  }
}
