part of 'chat_screen.dart';

// Menú modal de opciones de chat estilo iOS Grouped Glass.
extension _ChatScreenMenu on _ChatScreenState {
  void _showChatOptionsMenu(ChatState state, dynamic notifier) {
    HapticFeedback.selectionClick();
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is! NanoLightColors;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDark ? const Color(0xE6182130) : Colors.white.withValues(alpha: 0.95),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08), width: 0.8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 32, height: 3.5, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(2)))),
                Row(
                  children: [
                    Container(width: 26, height: 26, decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(7)), child: Icon(Icons.tune_rounded, size: 15, color: colors.primary)),
                    const SizedBox(width: 8),
                    Text('Gestión de Chat', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: colors.onSurface)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: isDark ? 0.35 : 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.20), width: 0.7),
                  ),
                  child: Column(
                    children: [
                      _buildCleanOptionTile(
                        icon: Icons.history_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        label: 'Historial de conversaciones',
                        subtitle: 'Restaura sesiones pasadas guardadas',
                        colors: colors,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showHistorySheet();
                        },
                      ),
                      _divider(colors),
                      _buildCleanOptionTile(
                        icon: Icons.add_comment_rounded,
                        iconColor: colors.primary,
                        label: 'Nueva conversación',
                        subtitle: 'Inicia un tema guardando el actual',
                        colors: colors,
                        onTap: state.generating ? null : () {
                          Navigator.pop(ctx);
                          _startNewConversation(notifier);
                        },
                      ),
                      _divider(colors),
                      _buildCleanOptionTile(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: const Color(0xFF818CF8),
                        label: 'Sesiones de IA Web',
                        subtitle: 'ChatGPT, DeepSeek, Claude, Gemini',
                        colors: colors,
                        onTap: () {
                          Navigator.pop(ctx);
                          AiWebSessionsSheet.show(context);
                        },
                      ),
                    ],
                  ),
                ),
                if (state.messages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: isDark ? 0.35 : 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.20), width: 0.7),
                    ),
                    child: Column(
                      children: [
                        _buildCleanOptionTile(
                          icon: Icons.chrome_reader_mode_rounded,
                          iconColor: const Color(0xFF60A5FA),
                          label: 'Modo lectura inmersivo',
                          subtitle: 'Formato libro limpio sin distracciones',
                          colors: colors,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _isReadingMode = true);
                          },
                        ),
                        _divider(colors),
                        _buildCleanOptionTile(
                          icon: Icons.picture_as_pdf_rounded,
                          iconColor: const Color(0xFFF43F5E),
                          label: 'Exportar chat a PDF',
                          subtitle: 'Documento estructurado listo para compartir',
                          colors: colors,
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _exportFullChatPdf(state);
                          },
                        ),
                        _divider(colors),
                        _buildCleanOptionTile(
                          icon: Icons.description_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Exportar a Markdown',
                          subtitle: 'Copia o guarda el texto con formato',
                          colors: colors,
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _exportFullChatMarkdown(state);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.22), width: 0.8),
                    ),
                    child: _buildCleanOptionTile(
                      icon: Icons.delete_sweep_rounded,
                      iconColor: const Color(0xFFEF4444),
                      label: 'Limpiar conversación actual',
                      subtitle: 'Elimina los mensajes de la pantalla activa',
                      colors: colors,
                      isDestructive: true,
                      onTap: state.generating ? null : () {
                        Navigator.pop(ctx);
                        _showClearDialog(notifier);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(NanoColors colors) => Divider(
    height: 1,
    thickness: 0.6,
    indent: 44,
    endIndent: 12,
    color: colors.outlineVariant.withValues(alpha: 0.20),
  );
}
