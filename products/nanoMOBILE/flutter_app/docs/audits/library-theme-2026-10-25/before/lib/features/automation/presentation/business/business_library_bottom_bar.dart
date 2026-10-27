import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'business_library_bottom_actions.dart';

/// Resumen y envío: concentra las acciones secundarias en un único menú.
class BusinessLibraryBottomBar extends StatelessWidget {
  final int totalCount, totalSizeBytes, selectedCount;
  final bool isSelectionMode, isChatPicker, isDark, canGenerate;
  final VoidCallback onSelectAll, onSendSelected, onGenerate;

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

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xC4142332),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2B3D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_outlined,
              size: 17,
              color: Color(0xFF9CB2C9),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalCount elementos',
                  style: const TextStyle(
                    color: Color(0xFFB9C8D8),
                    fontSize: 10.5,
                  ),
                ),
                Text(
                  '${_formatSize(totalSizeBytes)} en total',
                  style: const TextStyle(
                    color: Color(0xFF7F95AA),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            onPressed: selectedCount > 0 ? onSendSelected : null,
            minimumSize: const Size.square(34),
            padding: EdgeInsets.zero,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selectedCount > 0
                    ? const Color(0xFF0A84FF)
                    : const Color(0x7A126EE4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.paperplane_fill,
                    size: 14,
                    color: Color(0xE6FFFFFF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${isChatPicker ? 'Enviar' : 'Compartir'} ($selectedCount)',
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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

  String _formatSize(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
