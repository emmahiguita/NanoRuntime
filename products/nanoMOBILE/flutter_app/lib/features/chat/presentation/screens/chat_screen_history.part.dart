part of 'chat_screen.dart';

// QUÉ HACE:
// Despliega el panel de historial y gestión de sesiones guardadas localmente en el dispositivo.
//
// CÓMO FUNCIONA:
// - Abre un DraggableScrollableSheet con ámbito Overlay y Material garantizado.
// - Restaura el historial soberano desde ChatHistoryStore sin requerir conectividad de red.
// - Permite iniciar una nueva conversación limpia o restaurar un prompt previo en el campo de texto.
// - Delega la lista y tarjetas a `_HistoryListView` (en `chat_screen_history_view.part.dart`).
//
// POR QUÉ:
// Aplica principios SOLID (SRP) al separar la gestión del modal de la lista de tarjetas,
// manteniendo archivos concisos (< 120 líneas) y previniendo el error "No Overlay widget found".
extension _ChatScreenHistory on _ChatScreenState {
  /// QUÉ HACE: Despliega la hoja modal con el historial cronológico y botón de nuevo chat.
  /// CÓMO FUNCIONA: Usa showModalBottomSheet con ámbito Overlay dedicado y FutureBuilder sobre ChatHistoryStore.
  /// POR QUÉ: Brinda acceso rápido a consultas pasadas respetando la privacidad soberana on-device.
  Future<void> _showHistorySheet() async {
    HapticFeedback.selectionClick();
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final notifier = ref.read(chatProvider.notifier);

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (overlayContext) => DraggableScrollableSheet(
                initialChildSize: 0.72,
                minChildSize: 0.40,
                maxChildSize: 0.92,
                builder: (sheetContext, scrollCtrl) => Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    color: isDark ? const Color(0xF50D1526) : Colors.white.withValues(alpha: 0.98),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.20),
                        blurRadius: 30,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tirador ergonómico superior (drag handle)
                      Container(
                        width: 40,
                        height: 4.5,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      // Cabecera organizada
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.accent.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(Icons.history_rounded, color: colors.accent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Historial de Chat',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurface,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'Persistencia local soberana en dispositivo',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      color: colors.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón Nueva Ventana / Nueva Conversación
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.accent.withValues(alpha: 0.15),
                                foregroundColor: colors.accent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: colors.accent.withValues(alpha: 0.4)),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showClearDialog(notifier);
                              },
                              icon: const Icon(Icons.add_comment_rounded, size: 16),
                              label: const Text(
                                'Nuevo Chat',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Lista de mensajes delegada a componente especializado
                      Expanded(
                        child: FutureBuilder<List<ChatMessage>>(
                          future: ChatHistoryStore().restore(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator.adaptive());
                            }
                            final messages = snapshot.data ?? [];
                            return _HistoryListView(
                              messages: messages,
                              scrollCtrl: scrollCtrl,
                              colors: colors,
                              isDark: isDark,
                              onSelectPrompt: (promptText) {
                                Navigator.pop(ctx);
                                _textController.text = promptText;
                                _textController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _textController.text.length),
                                );
                                _focusNode.requestFocus();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
