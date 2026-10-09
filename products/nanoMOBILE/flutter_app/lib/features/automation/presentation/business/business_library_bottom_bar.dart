import 'package:flutter/material.dart';

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
          ElevatedButton.icon(
            onPressed: selectedCount > 0 ? onSendSelected : null,
            icon: const Icon(Icons.send_rounded, size: 15),
            label: Text(
              '${isChatPicker ? 'Enviar' : 'Compartir'} ($selectedCount)',
            ),
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: const Color(
                0xFF126EE4,
              ).withValues(alpha: .48),
              disabledForegroundColor: Colors.white70,
              backgroundColor: const Color(0xFF087BFF),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              minimumSize: const Size(0, 34),
              textStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 5),
          PopupMenuButton<String>(
            color: const Color(0xFF172638),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'all') onSelectAll();
              if (value == 'catalog') onGenerate();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'all',
                child: Text(
                  selectedCount == totalCount
                      ? 'Deseleccionar todo'
                      : 'Seleccionar todo',
                ),
              ),
              if (canGenerate)
                const PopupMenuItem(
                  value: 'catalog',
                  child: Text('Crear catálogo PDF'),
                ),
            ],
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: Color(0xFFA8B9CA),
            ),
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
