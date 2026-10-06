// QUÉ: alterna entre datos paginados y estadísticas profesionales.
// CÓMO: TabController conserva la selección mientras cambian consultas/tablas.
// POR QUÉ: concentra navegación visual sin contaminar las vistas responsivas.
//
// BUG CORREGIDO: _refresh() anterior no cancelaba el Future anterior → setState
// sobre widget ya desmontado. Ahora usa token (_rev) para descartar resultados obsoletos.

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/data_statistics_service.dart';
import '../../domain/data_models.dart' as dm;
import '../../domain/data_statistics.dart';
import 'database_data_grid.dart';
import 'database_profile_panel.dart';
import 'database_statistics_panel.dart';

class DatabaseWorkspaceTabs extends StatefulWidget {
  final dm.DataTable? table;
  final NanoColors colors;
  final void Function(int rowIndex, int columnIndex, dynamic newValue)? onCellEdit;

  const DatabaseWorkspaceTabs({
    super.key,
    required this.table,
    required this.colors,
    this.onCellEdit,
  });

  @override
  State<DatabaseWorkspaceTabs> createState() => _DatabaseWorkspaceTabsState();
}

class _DatabaseWorkspaceTabsState extends State<DatabaseWorkspaceTabs> {
  // Resultado del análisis estadístico; null mientras carga o sin tabla.
  DataStatisticsSnapshot? _snapshot;
  Object? _analysisError;
  bool _loading = false;

  // Token de versión: cada nueva tabla incrementa el contador.
  // La closure del Future captura su propio token; si no coincide con el actual,
  // descarta el resultado (evita setState sobre widget desmontado o datos viejos).
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    _refresh(); // Primer análisis al montar el widget
  }

  @override
  void didUpdateWidget(covariant DatabaseWorkspaceTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo re-analiza si la referencia de tabla cambió (evita trabajo duplicado)
    if (!identical(oldWidget.table, widget.table)) _refresh();
  }

  /// Lanza el análisis estadístico de forma segura:
  /// 1. Incrementa el token para invalidar resultados anteriores en vuelo.
  /// 2. Actualiza el estado solo si el widget sigue montado y el token coincide.
  void _refresh() {
    // Cada cambio invalida primero cualquier análisis que siga en vuelo.
    final token = ++_rev;
    final table = widget.table;

    // QUÉ: retira inmediatamente las cifras de la tabla anterior.
    // POR QUÉ: estadísticas viejas no deben presentarse como datos actuales.
    _snapshot = null;
    _analysisError = null;
    _loading = table != null;
    if (table == null) {
      // Sin tabla no hay trabajo asíncrono; el token ya anuló el Future anterior.
      return;
    }
    const DataStatisticsService()
        .analyze(table)
        .then(
          (result) {
            // Descarta si: widget desmontado O llegó una tabla más nueva
            if (!mounted || token != _rev) return;
            setState(() {
              _snapshot = result;
              _loading = false;
            });
          },
          onError: (Object error) {
            // Convierte fallos del motor nativo en estado visible y recuperable.
            if (!mounted || token != _rev) return;
            setState(() {
              _analysisError = error;
              _loading = false;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        // Barra de pestañas: Datos / Estadísticas / Perfil
        Material(
          color: widget.colors.surface,
          child: TabBar(
            labelColor: widget.colors.primary,
            unselectedLabelColor: widget.colors.onSurfaceVariant,
            indicatorColor: widget.colors.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.table_rows_rounded, size: 17),
                text: 'Datos',
              ),
              Tab(
                icon: Icon(Icons.analytics_rounded, size: 17),
                text: 'Estadísticas',
              ),
              Tab(
                icon: Icon(Icons.fact_check_outlined, size: 17),
                text: 'Perfil',
              ),
            ],
          ),
        ),
        // Contenido de cada pestaña — snapshot se pasa cuando ya está disponible
        Expanded(
          child: TabBarView(
            children: [
              DatabaseDataGrid(
                table: widget.table,
                colors: widget.colors,
                onCellEdit: widget.onCellEdit,
              ),
              _analysisBody(
                DatabaseStatisticsPanel(
                  snapshot: _snapshot,
                  colors: widget.colors,
                ),
              ),
              _analysisBody(
                DatabaseProfilePanel(
                  snapshot: _snapshot,
                  colors: widget.colors,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // Comparte carga y error entre las dos pestañas sin duplicar el análisis.
  Widget _analysisBody(Widget child) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_analysisError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No fue posible calcular el reporte estadístico.\n$_analysisError',
            textAlign: TextAlign.center,
            style: TextStyle(color: widget.colors.error),
          ),
        ),
      );
    }
    return child;
  }
}
