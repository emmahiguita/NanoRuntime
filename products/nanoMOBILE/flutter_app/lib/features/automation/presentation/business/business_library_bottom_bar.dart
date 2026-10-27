import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'business_library_bottom_actions.dart';

/// Resumen de archivos y acción real de envío. La selección vacía deshabilita
/// el botón; la superficie ligera hereda el tema sin otra capa de cristal.
class BusinessLibraryBottomBar extends StatelessWidget {
  const BusinessLibraryBottomBar({
    super.key,
    required this.totalCount,
    required this.totalSizeBytes,
    required this.selectedCount,
    required this.isSelectionMode,
    required this.isChatPicker,
    required this.isDark,
    required this.canGenerate,
    required this.onSelectAll,
    required this.onSendSelected,
    required this.onGenerate,
  });
  final int totalCount, totalSizeBytes, selectedCount;
  final bool isSelectionMode, isChatPicker, isDark, canGenerate;
  final VoidCallback onSelectAll, onSendSelected, onGenerate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: isDark ? .25 : .35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalCount elementos', style: TextStyle(color: colors.onSurface, fontSize: 11)),
                  Text(
                    '${_formatSize(totalSizeBytes)} en total',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FilledButton.icon(
                onPressed: selectedCount > 0 ? onSendSelected : null,
                icon: const Icon(CupertinoIcons.paperplane_fill, size: 14),
                label: Text(
                  '${isChatPicker ? 'Enviar' : 'Compartir'} ($selectedCount)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            BusinessLibraryBottomActions(
              allSelected: totalCount > 0 && selectedCount == totalCount,
              canGenerate: canGenerate,
              onSelectAll: onSelectAll,
              onGenerate: onGenerate,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
