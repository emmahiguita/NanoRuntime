// database_studio_landscape_view.dart
//
// QUÉ HACE:
// Vista horizontal (Landscape) adaptada para el Estudio de Base de Datos y SQL.
//
// CÓMO FUNCIONA:
// - Divide la pantalla en dos paneles horizontales (Row):
//   - Panel Izquierdo (42% del ancho, máx 360dp): selector de tablas, consola SQL
//     y barra de estado con scroll independiente (evita overflow en landscape corto).
//   - Panel Derecho (Expanded): cuadrícula de datos a pantalla completa.
// - Aplica tipografía mobile profesional (Inter y JetBrainsMono).
//
// POR QUÉ:
// BUG CORREGIDO: Column con MainAxisSize.min dentro de Expanded causaba overflow rojo
// cuando el contenido superaba la altura disponible en landscape compacto.
// Solución: Column con CrossAxisAlignment.stretch y Expanded en la consola.

library;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import '../widgets/database_workspace_tabs.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // El panel de control cede espacio a los datos en teléfonos horizontales.
        // clamp(260, 360): ni tan estrecho que corte labels, ni tan ancho que quite datos.
        final railWidth = (constraints.maxWidth * 0.42).clamp(260.0, 360.0);

        return Row(
          children: [
            // ── Panel Izquierdo: Controles (Selector + Consola SQL + Estado) ──
            SizedBox(
              width: railWidth,
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
                // Column sin MainAxisSize.min: respeta el height del Row completo
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Chips de selección de tabla (altura fija 48dp)
                    DatabaseTableSelector(
                      state: state,
                      controller: controller,
                      colors: colors,
                    ),

                    // 2. Consola SQL: ocupa el espacio restante y es scrollable
                    //    Expanded evita el overflow rojo en landscape compacto
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: DatabaseSqlConsole(
                          queryController: queryController,
                          state: state,
                          controller: controller,
                          colors: colors,
                        ),
                      ),
                    ),

                    // 3. Banner de estado/error (altura variable, pegado al fondo)
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

            // ── Panel Derecho: Cuadrícula de Datos (ocupa el resto) ──
            Expanded(
              child: Container(
                color: colors.background,
                child: DatabaseWorkspaceTabs(
                  table: state.activeDisplayTable,
                  colors: colors,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
