part of 'chat_screen.dart';

// QUÉ HACE:
// Menú modal de opciones del chat depurado, profesional y sin opciones redundantes.
//
// CÓMO FUNCIONA:
// - Abre un panel de cristal esmerilado con opciones organizadas por categorías claras.
// - "Nueva conversación" inicia un chat limpio guardando el anterior en el historial soberano.
// - "Limpiar conversación" queda como acción destructiva explícita al final del modal.
// - Proporciona exportación a PDF, Markdown y cambio al modo lectura inmersivo.
//
// POR QUÉ:
// Corrige los errores de diseño, elimina acciones duplicadas confusas y respeta
// Clean Architecture, Material Expressive y el límite de archivos menores a 200 líneas.
extension _ChatScreenMenu on _ChatScreenState {
  /// QUÉ HACE: Despliega las opciones del chat en un modal elegante de cristal esmerilado.
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
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? const Color(0xF20F172A) : Colors.white.withValues(alpha: 0.98),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tirador ergonómico superior
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título de sección profesional
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Gestión de Chat',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 1. Historial de conversaciones
            _buildCleanOptionTile(
              icon: Icons.history_rounded,
              label: 'Historial de conversaciones',
              subtitle: 'Revisa y restaura sesiones pasadas guardadas',
              colors: colors,
              onTap: () {
                Navigator.pop(ctx);
                _showHistorySheet();
              },
            ),

            // 2. Nueva conversación limpia (no destructiva, archiva en historial)
            _buildCleanOptionTile(
              icon: Icons.add_comment_rounded,
              label: 'Nueva conversación',
              subtitle: 'Comienza un nuevo tema guardando el actual',
              colors: colors,
              onTap: state.generating
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _startNewConversation(notifier);
                    },
            ),

            // 3. Sesiones de IA Externa
            _buildCleanOptionTile(
              icon: Icons.auto_awesome_rounded,
              label: 'Sesiones de IA Web (ChatGPT, DeepSeek…)',
              subtitle: 'Navega y chatea con asistentes en la nube',
              colors: colors,
              onTap: () {
                Navigator.pop(ctx);
                AiWebSessionsSheet.show(context);
              },
            ),

            // Opciones contextuales activas con mensajes
            if (state.messages.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: colors.onSurface.withValues(alpha: 0.08), height: 1),
              ),
              _buildCleanOptionTile(
                icon: Icons.chrome_reader_mode_rounded,
                label: 'Modo lectura inmersivo',
                subtitle: 'Visualiza la conversación en formato libro sin barras',
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _isReadingMode = true);
                },
              ),
              _buildCleanOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Exportar chat a PDF',
                subtitle: 'Genera un documento estructurado para compartir',
                colors: colors,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportFullChatPdf(state);
                },
              ),
              _buildCleanOptionTile(
                icon: Icons.description_rounded,
                label: 'Exportar a Markdown',
                subtitle: 'Copia o guarda el texto con formato markdown',
                colors: colors,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportFullChatMarkdown(state);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: colors.onSurface.withValues(alpha: 0.08), height: 1),
              ),
              // 4. Acción destructiva explícita (Limpiar mensajes actuales)
              _buildCleanOptionTile(
                icon: Icons.delete_sweep_rounded,
                label: 'Limpiar conversación actual',
                subtitle: 'Elimina permanentemente los mensajes de la pantalla',
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
