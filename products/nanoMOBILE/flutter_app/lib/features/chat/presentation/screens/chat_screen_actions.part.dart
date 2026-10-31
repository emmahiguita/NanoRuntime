part of 'chat_screen.dart';

// chat_screen_actions.part.dart — Acciones superiores flotantes del chat en Liquid Glass.
// QUÉ HACE: Despliega la cápsula de estado del motor, botón de nuevo tema y acceso al menú de gestión.
// CÓMO FUNCIONA: Usa botones Liquid Glass con CupertinoIcons (square_pencil, ellipsis) y respuesta táctil.
// POR QUÉ: Depura iconos flotantes y sustituye botones genéricos por iconografía profesional iOS (< 160 líneas).

extension _ChatScreenActions on _ChatScreenState {
  Widget _chatActions(
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors, {
    required bool landscape,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loading = state.connection == ModelConnectionState.loadingModel;
    final isOnline = state.engineOnline;

    final Color statusColor = loading
        ? const Color(0xFF38BDF8)
        : (isOnline ? const Color(0xFF34C759) : const Color(0xFF94A3B8));

    final String statusLabel = loading
        ? 'Cargando'
        : (isOnline ? 'Activo' : 'Detenido');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Cápsula de Estado Liquid Glass "● Activo" / "○ Detenido"
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/models');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surface.withValues(alpha: 0.45)
                        : colors.surface.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(
                        alpha: isDark ? 0.35 : 0.25,
                      ),
                      width: 0.7,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: [
                            if (isOnline || loading)
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.65),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                          letterSpacing: -0.1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 2. Botón Nuevo Chat con CupertinoIcons.square_pencil
        Semantics(
          label: 'Nueva conversación',
          button: true,
          child: _buildActionIconButton(
            icon: CupertinoIcons.square_pencil,
            tooltip: 'Nueva conversación',
            onTap: state.generating
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    _startNewConversation(notifier);
                  },
            colors: colors,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 5),

        // 3. Menú de opciones (Gestión de Chat) con CupertinoIcons.ellipsis
        Semantics(
          label: 'Gestión de chat y opciones',
          button: true,
          child: _buildActionIconButton(
            icon: CupertinoIcons.ellipsis,
            tooltip: 'Gestión de chat',
            onTap: () {
              HapticFeedback.selectionClick();
              _showChatOptionsMenu(state, notifier);
            },
            colors: colors,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  /// Construye un botón circular Liquid Glass con iconografía profesional.
  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required NanoColors colors,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: isDark
                ? colors.surface.withValues(alpha: 0.45)
                : colors.surface.withValues(alpha: 0.70),
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outlineVariant.withValues(
                      alpha: isDark ? 0.35 : 0.25,
                    ),
                    width: 0.7,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 16,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}