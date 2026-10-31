part of 'chat_screen.dart';

// chat_screen_menu.part.dart — Menú modal contextual de "Gestión de Chat" estilo iOS Liquid Glass.
// QUÉ HACE: Despliega el panel de opciones de sesión, herramientas de lectura y exportación.
// CÓMO FUNCIONA: Lista directa continua sobre la superficie de cristal, sin cards internas, con tipografía Inter.
// POR QUÉ: Depura contenedores pesados y colores saturados para una experiencia iOS profesional (< 150 líneas).

extension _ChatScreenMenu on _ChatScreenState {
  void _showChatOptionsMenu(ChatState state, dynamic notifier) {
    HapticFeedback.selectionClick();
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    showNanoGlassWindow(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera limpia
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 17,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gestión de Chat',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Grupo 1: Conversación
            _menuSectionHeader('CONVERSACIÓN', colors),
            _buildCleanOptionTile(
              icon: CupertinoIcons.clock,
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
              icon: CupertinoIcons.square_pencil,
              label: 'Nueva conversación',
              subtitle: 'Inicia un tema guardando el actual',
              colors: colors,
              onTap: state.generating
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _startNewConversation(notifier);
                    },
            ),
            _divider(colors),
            _buildCleanOptionTile(
              icon: CupertinoIcons.sparkles,
              label: 'Sesiones de IA Web',
              subtitle: 'ChatGPT, DeepSeek, Claude, Gemini',
              colors: colors,
              onTap: () {
                Navigator.pop(ctx);
                AiWebSessionsSheet.show(context);
              },
            ),

            if (state.messages.isNotEmpty) ...[
              _menuSectionHeader('HERRAMIENTAS Y EXPORTACIÓN', colors),
              _buildCleanOptionTile(
                icon: CupertinoIcons.book,
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
                icon: CupertinoIcons.doc_text,
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
                icon: CupertinoIcons.doc_plaintext,
                label: 'Exportar a Markdown',
                subtitle: 'Copia o guarda el texto con formato',
                colors: colors,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportFullChatMarkdown(state);
                },
              ),

              _menuSectionHeader('ACCIONES', colors),
              _buildCleanOptionTile(
                icon: CupertinoIcons.trash,
                label: 'Limpiar conversación actual',
                subtitle: 'Elimina los mensajes de la pantalla activa',
                colors: colors,
                isDestructive: true,
                onTap: state.generating
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _showClearDialog(notifier);
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
