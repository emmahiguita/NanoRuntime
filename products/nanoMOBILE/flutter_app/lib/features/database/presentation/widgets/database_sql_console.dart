import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../../application/database_studio_controller.dart';

/// Componente modular para el editor de consultas SQL y barra de snippets
class DatabaseSqlConsole extends StatelessWidget {
  final TextEditingController queryController;
  final DatabaseStudioState state;
  final DatabaseStudioController controller;
  final NanoColors colors;

  const DatabaseSqlConsole({
    super.key,
    required this.queryController,
    required this.state,
    required this.controller,
    required this.colors,
  });

  void _insertSnippet(String snippet) {
    if (snippet.startsWith('SELECT')) {
      queryController.text = snippet;
    } else {
      queryController.text = '${queryController.text}$snippet';
    }
    controller.updateQueryText(queryController.text);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
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
                      _buildSnippetChip(
                        'SELECT *',
                        () => _insertSnippet('SELECT * FROM ${state.selectedTableName} LIMIT 25;'),
                      ),
                      const SizedBox(width: 4),
                      _buildSnippetChip(
                        'COUNT(*)',
                        () => _insertSnippet('SELECT COUNT(*) FROM ${state.selectedTableName};'),
                      ),
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
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: queryController,
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
                label: const Text(
                  'Ejecutar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: state.isLoading
                    ? null
                    : () {
                        controller.updateQueryText(queryController.text);
                        controller.executeCurrentQuery();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
