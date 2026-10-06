part of 'chat_screen.dart';

// QUÉ HACE:
// Barra de acciones superiores del chat: cápsula de motor/modelo, historial, nuevo chat y opciones.
//
// CÓMO FUNCIONA:
// - Despliega cápsula cristalina interactiva vinculada a la pantalla de modelos.
// - Evita colores ámbar/naranjas de `onSurfaceVariant` utilizando tonos neutros de cristal esmerilado.
// - Proporciona accesos directos de un toque para ver el historial y crear nuevas conversaciones.
// - Elimina tooltips propensos a "No Overlay" y los sustituye por accesibilidad semántica nativa.
//
// POR QUÉ:
// Resuelve directamente los errores visuales de diseño, depura opciones duplicadas y asegura
// cumplimiento de Clean Architecture y la regla de archivos menores a 200 líneas.
extension _ChatScreenActions on _ChatScreenState {
  /// QUÉ HACE: Construye las acciones superiores alineadas a la derecha de la barra de título.
  Widget _chatActions(
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors, {
    required bool landscape,
  }) {
    final isDark = colors is NanoDarkColors;
    final loading = state.connection == ModelConnectionState.loadingModel;

    // QUÉ HACE: Paleta limpia neutral sin tintes naranjas o amarillos heredados de colorScheme.
    final Color engineDotColor;
    final Color engineBgColor;
    final Color engineBorderColor;

    if (loading) {
      engineDotColor = const Color(0xFF22D3EE); // Cian brillante
      engineBgColor = const Color(0xFF22D3EE).withValues(alpha: 0.12);
      engineBorderColor = const Color(0xFF22D3EE).withValues(alpha: 0.35);
    } else if (state.engineOnline) {
      engineDotColor = const Color(0xFF10B981); // Verde esmeralda activo
      engineBgColor = const Color(0xFF10B981).withValues(alpha: 0.12);
      engineBorderColor = const Color(0xFF10B981).withValues(alpha: 0.32);
    } else {
      engineDotColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8); // Slate neutro
      engineBgColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05);
      engineBorderColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10);
    }

    final engineLabel = loading
        ? 'Cargando…'
        : (state.engineOnline
              ? (state.activeModel.isNotEmpty ? state.activeModel : 'Activo')
              : 'Detenido');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Cápsula interactiva del motor/modelo (Estilo Dynamic Island Glass)
        GestureDetector(
          onTap: () => context.go('/models'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: engineBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: engineBorderColor, width: 0.9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: engineDotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (state.engineOnline || loading)
                        BoxShadow(
                          color: engineDotColor.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: landscape ? 120 : 76),
                  child: Text(
                    engineLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: colors.onSurface.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),

        // 2. Botón de acceso directo al Historial (en Landscape por espacio, en Portrait accesible vía menú)
        if (landscape)
          Semantics(
            label: 'Ver historial de conversaciones',
            button: true,
            child: IconButton(
              key: const ValueKey('chat_history_button'),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(5),
              icon: Icon(
                Icons.history_rounded,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.80),
              ),
              onPressed: _showHistorySheet,
            ),
          ),

        // 3. Botón directo de Nueva Conversación (guarda la anterior y abre chat fresco)
        Semantics(
          label: 'Nueva conversación limpia',
          button: true,
          child: IconButton(
            key: const ValueKey('chat_new_conversation_button'),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(5),
            icon: Icon(
              Icons.add_comment_outlined,
              size: 19,
              color: colors.onSurface.withValues(alpha: 0.80),
            ),
            onPressed: state.generating ? null : () => _startNewConversation(notifier),
          ),
        ),

        // 4. Menú de opciones avanzadas (Lectura, Exportación, Limpieza profunda)
        Semantics(
          label: 'Más opciones de chat',
          button: true,
          child: IconButton(
            key: const ValueKey('chat_overflow_menu'),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.more_vert_rounded,
              color: colors.onSurface.withValues(alpha: 0.75),
              size: 19,
            ),
            onPressed: () => _showChatOptionsMenu(state, notifier),
          ),
        ),
      ],
    );
  }
}
