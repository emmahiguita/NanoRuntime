import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';

/// Pantalla Principal del Estudio de Bases de Datos, Hojas de Cálculo Shell y Generación de Informes
class DatabaseStudioScreen extends ConsumerStatefulWidget {
  const DatabaseStudioScreen({super.key});

  @override
  ConsumerState<DatabaseStudioScreen> createState() => _DatabaseStudioScreenState();
}

class _DatabaseStudioScreenState extends ConsumerState<DatabaseStudioScreen> {
  late final TextEditingController _queryController;
  final TextEditingController _shellPathController = TextEditingController(
    text: '/data/data/dev.nanoai.mobile/files/nano/reporte.csv',
  );

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(databaseStudioControllerProvider).currentQuery;
    _queryController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _shellPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final state = ref.watch(databaseStudioControllerProvider);
    final controller = ref.read(databaseStudioControllerProvider.notifier);

    // Sincronizar controlador si cambia externamente
    if (_queryController.text != state.currentQuery && !FocusScope.of(context).hasFocus) {
      _queryController.text = state.currentQuery;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.85),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.table_chart_rounded, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Data Studio & SQL',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'Hojas de cálculo Shell, SQLite y Reportes PDF',
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Botón Conectar Hoja de Shell / Importar
          IconButton(
            tooltip: 'Conectar Hoja Shell',
            icon: Icon(Icons.add_link_rounded, color: colors.primary, size: 22),
            onPressed: () => _showConnectShellDialog(context, controller, colors),
          ),
          // Botón Exportar a Shell
          IconButton(
            tooltip: 'Exportar a Shell',
            icon: Icon(Icons.terminal_rounded, color: colors.accent, size: 22),
            onPressed: () => _exportToShell(context, controller),
          ),
          // Botón Generar Informe PDF
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
              label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showPdfConfigModal(context, controller, colors),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Selector de Tablas y Fuentes Activas
          _buildTableSelector(state, controller, colors),

          // 2. Editor de Consultas SQL con snippets
          _buildSqlConsole(state, controller, colors),

          // 3. Barra de Estado / Mensajes
          if (state.errorMessage != null)
            _buildErrorBanner(state.errorMessage!, colors)
          else if (state.statusMessage != null)
            _buildStatusBar(state.statusMessage!, state.queryResult?.executionTimeMs, colors),

          // 4. Visualizador de la Tabla de Datos
          Expanded(
            child: _buildDataGrid(state, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSelector(
    DatabaseStudioState state,
    DatabaseStudioController controller,
    NanoColors colors,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final entry in state.tables.entries) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.key.contains('shell') ? Icons.terminal : Icons.table_rows_rounded,
                      size: 14,
                      color: state.selectedTableName == entry.key ? colors.primary : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: state.selectedTableName == entry.key ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.rowCount}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                selected: state.selectedTableName == entry.key,
                selectedColor: colors.primary.withValues(alpha: 0.18),
                backgroundColor: colors.surface,
                onSelected: (selected) {
                  if (selected) {
                    controller.selectTable(entry.key);
                    _queryController.text = 'SELECT * FROM ${entry.key} LIMIT 50;';
                  }
                },
              ),
            ),
          ],
          ActionChip(
            avatar: const Icon(Icons.file_open_outlined, size: 14),
            label: const Text('Cargar Archivo', style: TextStyle(fontSize: 11)),
            onPressed: () => controller.importFileFromDevice(),
          ),
        ],
      ),
    );
  }

  Widget _buildSqlConsole(
    DatabaseStudioState state,
    DatabaseStudioController controller,
    NanoColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SQL / SHELL',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildSnippetChip('SELECT *', () => _insertSnippet('SELECT * FROM ${state.selectedTableName} LIMIT 25;')),
                      const SizedBox(width: 4),
                      _buildSnippetChip('COUNT(*)', () => _insertSnippet('SELECT COUNT(*) FROM ${state.selectedTableName};')),
                      const SizedBox(width: 4),
                      _buildSnippetChip('WHERE', () => _insertSnippet(' WHERE ')),
                      const SizedBox(width: 4),
                      _buildSnippetChip('ORDER BY', () => _insertSnippet(' ORDER BY ')),
                      const SizedBox(width: 4),
                      _buildSnippetChip('GROUP BY', () => _insertSnippet(' GROUP BY ')),
                      const SizedBox(width: 4),
                      _buildSnippetChip('LIMIT 50', () => _insertSnippet(' LIMIT 50;')),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: _queryController,
                    onChanged: controller.updateQueryText,
                    onSubmitted: (_) => controller.executeCurrentQuery(),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.5,
                    ),
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Ej: SELECT * FROM ventas_globales WHERE total > 5000 ORDER BY total DESC;',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: state.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Ejecutar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: state.isLoading
                    ? null
                    : () {
                        controller.updateQueryText(_queryController.text);
                        controller.executeCurrentQuery();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSnippetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _insertSnippet(String snippet) {
    if (snippet.startsWith('SELECT')) {
      _queryController.text = snippet;
    } else {
      _queryController.text = '${_queryController.text}$snippet';
    }
    ref.read(databaseStudioControllerProvider.notifier).updateQueryText(_queryController.text);
  }

  Widget _buildStatusBar(String message, int? latency, NanoColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: colors.surfaceVariant.withValues(alpha: 0.25),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 14, color: colors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11.5, color: colors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (latency != null)
            Text(
              '${latency}ms',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.accent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error, NanoColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: colors.error.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(fontSize: 12, color: colors.error, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataGrid(DatabaseStudioState state, NanoColors colors) {
    final table = state.activeDisplayTable;

    if (table == null || table.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_chart_outlined, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No hay registros para mostrar',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Ejecute una consulta o conecte una hoja de cálculo',
              style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTableTheme(
                data: DataTableThemeData(
                  headingRowColor: WidgetStateProperty.all(colors.surfaceVariant.withValues(alpha: 0.5)),
                  dataRowColor: WidgetStateProperty.resolveWith<Color>((states) {
                    return colors.surface;
                  }),
                  headingTextStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                  dataTextStyle: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.5,
                    color: colors.onSurface,
                  ),
                  horizontalMargin: 12,
                  columnSpacing: 20,
                  dividerThickness: 0.5,
                ),
                child: DataTable(
                  columns: table.columns.map((col) {
                    return DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(col),
                          const SizedBox(width: 4),
                          Text(
                            table.columnTypes[col]?.name.toUpperCase() ?? '',
                            style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  rows: [
                    for (int r = 0; r < table.rows.length; r++)
                      DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>((states) {
                          return r.isEven ? colors.surface : colors.surfaceVariant.withValues(alpha: 0.15);
                        }),
                        cells: [
                          for (int c = 0; c < table.columns.length; c++)
                            DataCell(
                              Text(
                                c < table.rows[r].length ? (table.rows[r][c]?.toString() ?? '-') : '-',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Modales y Acciones ---

  void _showConnectShellDialog(
    BuildContext context,
    DatabaseStudioController controller,
    NanoColors colors,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Icon(Icons.terminal_rounded, color: colors.primary),
            const SizedBox(width: 8),
            const Text('Conectar Hoja Shell', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indique la ruta del archivo CSV o TSV generado por scripts o comandos dentro del entorno Shell:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shellPathController,
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Ruta absoluta en Shell',
                hintText: '/data/data/dev.nanoai.mobile/files/nano/...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('reporte.csv', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    _shellPathController.text = '/data/data/dev.nanoai.mobile/files/nano/reporte.csv';
                  },
                ),
                ActionChip(
                  label: const Text('metricas.tsv', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    _shellPathController.text = '/data/data/dev.nanoai.mobile/files/nano/metricas.tsv';
                  },
                ),
                ActionChip(
                  label: const Text('Descargas SD', style: TextStyle(fontSize: 10)),
                  onPressed: () {
                    _shellPathController.text = '/sdcard/Download/datos.csv';
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final targetPath = _shellPathController.text.trim();
              Navigator.pop(ctx);
              final ok = await controller.importFromShellPath(targetPath);
              if (!mounted) return;
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('No se pudo conectar con $targetPath'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
  }

  void _showPdfConfigModal(
    BuildContext context,
    DatabaseStudioController controller,
    NanoColors colors,
  ) {
    final titleCtrl = TextEditingController(text: 'Informe Ejecutivo - Datos Shell');
    final notesCtrl = TextEditingController(text: 'Generado automáticamente desde NanoAI Data Studio.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded, color: colors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Generar Informe Ejecutivo PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Título del Informe',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notas o Conclusiones',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Compartir PDF'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      controller.shareCurrentReport(title: titleCtrl.text.trim());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Ver / Imprimir'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      controller.generateAndPreviewPdfReport(
                        title: titleCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _exportToShell(BuildContext context, DatabaseStudioController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await controller.exportToShellDirectory();
    if (!mounted) return;
    if (path != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Guardado en entorno Shell: $path'),
          backgroundColor: Colors.teal,
          action: SnackBarAction(
            label: 'Copiar Ruta',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
            },
          ),
        ),
      );
    }
  }
}
