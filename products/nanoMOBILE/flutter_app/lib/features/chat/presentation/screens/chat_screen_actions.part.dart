part of 'chat_screen.dart';

/// Barra de acciones superiores compacta estilo iOS Translucent Glass.
extension _ChatScreenActions on _ChatScreenState {
  Widget _chatActions(
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors, {
    required bool landscape,
  }) {
    final loading = state.connection == ModelConnectionState.loadingModel;
    final isOnline = state.engineOnline;

    final Color statusColor = loading
        ? const Color(0xFF22D3EE)
        : (isOnline ? const Color(0xFF48D9A7) : const Color(0xFF94A3B8));

    final String statusLabel = loading
        ? 'Cargando'
        : (isOnline ? 'Activo' : 'Detenido');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Cápsula de Estado iOS Glass "■ Detenido" / "● Activo"
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/models');
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 0.75,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: isOnline ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: isOnline ? null : BorderRadius.circular(1),
                          color: statusColor,
                          boxShadow: [
                            if (isOnline || loading)
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE2EBF5),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),

        // 2. Botón Nueva Conversación
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.white.withValues(alpha: 0.07),
              child: InkWell(
                onTap: state.generating ? null : () => _startNewConversation(notifier),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(Icons.add_comment_outlined, size: 15, color: Color(0xFFC8DCF0)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 3),

        // 3. Menú de opciones avanzadas (3 dots)
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.white.withValues(alpha: 0.07),
              child: InkWell(
                onTap: () => _showChatOptionsMenu(state, notifier),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFFC8DCF0)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
