part of 'chat_screen.dart';

extension _ChatScreenMenu on _ChatScreenState {
  /// Despliega las opciones del chat en un modal elegante y adaptativo
  /// inmune a ausencias de Overlay.
  void _showChatOptionsMenu(ChatState state, dynamic notifier) {
    HapticFeedback.selectionClick();
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isDark
              ? const Color(0xF2101726)
              : Colors.white.withValues(alpha: 0.96),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildChatOptionTile(
              icon: Icons.smart_toy_rounded,
              label: 'Invocar Asistente Búho AI',
              colors: colors,
              onTap: () {
                Navigator.pop(ctx);
                NanoFloatingWrapper.expand();
              },
            ),
            if (state.messages.isNotEmpty) ...[
              _buildChatOptionTile(
                icon: Icons.chrome_reader_mode_rounded,
                label: 'Modo lectura',
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _isReadingMode = true);
                },
              ),
              _buildChatOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Exportar chat a PDF',
                colors: colors,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportFullChatPdf(state);
                },
              ),
              _buildChatOptionTile(
                icon: Icons.description_rounded,
                label: 'Exportar a Markdown',
                colors: colors,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportFullChatMarkdown(state);
                },
              ),
              Divider(color: colors.outline.withValues(alpha: 0.15)),
              _buildChatOptionTile(
                icon: Icons.delete_sweep_rounded,
                label: 'Limpiar conversación',
                colors: colors,
                isDestructive: true,
                onTap: state.generating
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _showClearDialog(notifier);
                      },
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No hay mensajes en esta conversación',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatOptionTile({
    required IconData icon,
    required String label,
    required NanoColors colors,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : colors.onSurface.withValues(alpha: 0.85);

    return ListTile(
      dense: true,
      enabled: onTap != null,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
