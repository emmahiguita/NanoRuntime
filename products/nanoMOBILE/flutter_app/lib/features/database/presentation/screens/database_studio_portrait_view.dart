// database_studio_portrait_view.dart
//
// QUÉ HACE:
// Vista vertical (Portrait) para el Estudio de Base de Datos y SQL.
//
// CÓMO FUNCIONA:
// - Apila verticalmente el selector de tablas, consola SQL, barra de estado y la cuadrícula de datos.
// - Conecta callbacks para sincronizar el editor SQL al cambiar de tabla activa.
//
// POR QUÉ:
// Aplica SRP separando la disposición de pantalla vertical de la lógica de negocio (< 100 líneas).

library;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import '../widgets/database_data_grid.dart';
import '../widgets/database_sql_console.dart';
import '../widgets/database_status_banner.dart';
import '../widgets/database_table_selector.dart';

class DatabaseStudioPortraitView extends StatelessWidget {
  final DatabaseStudioState state;
  final DatabaseStudioController controller;
  final TextEditingController queryController;
  final NanoColors colors;

  const DatabaseStudioPortraitView({
    super.key,
    required this.state,
    required this.controller,
    required this.queryController,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Selector de Tablas y Fuentes Activas
        DatabaseTableSelector(
          state: state,
          controller: controller,
          colors: colors,
          onTableSelected: (tableName) {
            queryController.text = 'SELECT * FROM $tableName LIMIT 50;';
          },
        ),

        // 2. Editor de Consultas SQL y Snippets
        DatabaseSqlConsole(
          queryController: queryController,
          state: state,
          controller: controller,
          colors: colors,
        ),

        // 3. Barra de Estado o Errores
        DatabaseStatusBanner(
          errorMessage: state.errorMessage,
          statusMessage: state.statusMessage,
          latencyMs: state.queryResult?.executionTimeMs,
          colors: colors,
        ),

        // 4. Cuadrícula de Datos
        Expanded(
          child: DatabaseDataGrid(
            table: state.activeDisplayTable,
            colors: colors,
          ),
        ),
      ],
    );
  }
}
