part of 'chat_screen.dart';

extension _ChatScreenActions on _ChatScreenState {
  /// QUÉ HACE: muestra el estado del motor, acceso al búho y el menú de chat.
  /// POR QUÉ: lectura, exportación y limpieza permanecen en ⋮ para evitar que
  /// la fila del encabezado exceda el ancho disponible en móviles.
  Widget _chatActions(
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors, {
    required bool landscape,
  }) {
    final loading = state.connection == ModelConnectionState.loadingModel;
    // QUÉ HACE: reserva el verde para el motor activo y el color de marca para carga.
    // POR QUÉ: el estado detenido es informativo y no debe parecer una franja de alerta.
    final engineColor = loading
        ? colors.primary
        : state.engineOnline
        ? colors.success
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final engineLabel = loading
        ? 'Cargando…'
        : (state.engineOnline
              ? (state.activeModel.isNotEmpty ? state.activeModel : 'Activo')
              : 'Detenido');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador interactivo del modelo / motor (Dynamic Island Capsule iOS Style)
        GestureDetector(
          onTap: () => context.go('/models'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: engineColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: engineColor.withValues(alpha: 0.35),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: engineColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: BoxDecoration(
                    color: engineColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: engineColor,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 86),
                  child: Text(
                    engineLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: colors.onSurface.withValues(alpha: 0.90),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),

        // QUÉ HACE: deja el acceso a lectura dentro de ⋮, donde sigue disponible.
        // POR QUÉ: evita duplicar el botón y libera 30 px en el encabezado móvil.
        // Invocar Asistente Búho AI bajo demanda (evita que esté fijo en pantalla)
        Semantics(
          label: 'Invocar Asistente Búho',
          button: true,
          child: IconButton(
            key: const ValueKey('chat_invoke_owl_button'),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: const EdgeInsets.all(5),
            icon: Icon(
              Icons.smart_toy_outlined,
              size: 19,
              color: colors.primary,
            ),
            onPressed: () => NanoFloatingWrapper.toggle(),
          ),
        ),

        // Menú ⋮ con exportación y limpieza (libre de PopupMenuButton para erradicar el error "No Overlay")
        Semantics(
          label: 'Más opciones',
          button: true,
          child: IconButton(
            key: const ValueKey('chat_overflow_menu'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
