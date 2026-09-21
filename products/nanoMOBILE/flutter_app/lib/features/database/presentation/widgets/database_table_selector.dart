import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';

/// Componente modular para la selección horizontal de tablas y fuentes de datos
class DatabaseTableSelector extends StatelessWidget {
  final DatabaseStudioState state;
  final DatabaseStudioController controller;
  final NanoColors colors;
  final ValueChanged<String>? onTableSelected;

  const DatabaseTableSelector({
    super.key,
    required this.state,
    required this.controller,
    required this.colors,
    this.onTableSelected,
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
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.key.contains('shell')
                          ? Icons.terminal
                          : Icons.table_rows_rounded,
                      size: 14,
                      color: state.selectedTableName == entry.key
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.rowCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
                    onTableSelected?.call(entry.key);
                  }
                },
              ),
            ),
          ],
          ActionChip(
            avatar: const Icon(Icons.file_open_outlined, size: 14),
            label: const Text('Cargar Archivo', style: TextStyle(fontSize: 11)),
            backgroundColor: colors.surface,
            onPressed: () => controller.importFileFromDevice(),
          ),
        ],
      ),
    );
  }
}
