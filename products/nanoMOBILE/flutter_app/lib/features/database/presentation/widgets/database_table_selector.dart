// database_table_selector.dart
//
// QUÉ HACE:
// Barra horizontal de pestañas y chips de tablas activas, archivos locales y Google Sheets.
//
// CÓMO FUNCIONA:
// - Muestra ChoiceChips por cada tabla cargada con su conteo de filas y tipo de fuente.
// - Resalta con icono especial y color esmeralda si la tabla proviene de Google Sheets con sincronización en vivo.
// - Provee accesos rápidos para cargar archivos locales o conectar / configurar Google Sheets.
//
// POR QUÉ:
// Optimiza la navegación en pantallas móviles y horizontales manteniendo baja densidad visual (< 150 líneas).

library;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';
import 'database_google_sheet_dialog.dart';

class DatabaseTableSelector extends StatelessWidget {
  final DatabaseStudioState state;
  final DatabaseStudioController controller;
  final NanoColors colors;

  const DatabaseTableSelector({
    super.key,
    required this.state,
    required this.controller,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final entry in state.tables.entries) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.value.isGoogleSheet
                          ? (state.isLiveSyncActive
                              ? Icons.sensors_rounded
                              : Icons.table_chart_rounded)
                          : (entry.key.contains('shell')
                              ? Icons.terminal
                              : Icons.table_rows_rounded),
                      size: 14,
                      color: entry.value.isGoogleSheet
                          ? const Color(0xFF10B981)
                          : (state.selectedTableName == entry.key
                              ? colors.primary
                              : colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key.replaceAll('_', ' '),
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: state.selectedTableName == entry.key
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.value.rowCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                selected: state.selectedTableName == entry.key,
                selectedColor: entry.value.isGoogleSheet
                    ? const Color(0xFF10B981).withValues(alpha: 0.18)
                    : colors.primary.withValues(alpha: 0.18),
                backgroundColor: colors.surface,
                onSelected: (selected) {
                  if (selected) {
                    controller.selectTable(entry.key);
                  }
                },
              ),
            ),
          ],
          ActionChip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.file_open_outlined, size: 14),
            label: const Text('Cargar Archivo', style: TextStyle(fontSize: 11)),
            backgroundColor: colors.surface,
            onPressed: () => controller.importFileFromDevice(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ActionChip(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                state.isLiveSyncActive
                    ? Icons.sync_rounded
                    : Icons.cloud_download_rounded,
                size: 14,
                color: state.isLiveSyncActive
                    ? const Color(0xFF10B981)
                    : colors.primary,
              ),
              label: Text(
                state.isLiveSyncActive ? 'Sheets (En vivo)' : 'Google Sheets',
                style: TextStyle(
                  fontSize: 11,
                  color: state.isLiveSyncActive
                      ? const Color(0xFF10B981)
                      : null,
                  fontWeight: state.isLiveSyncActive
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              backgroundColor: state.isLiveSyncActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : colors.surface,
              onPressed: () =>
                  DatabaseGoogleSheetDialog.show(context, controller),
            ),
          ),
        ],
      ),
    );
  }
}
