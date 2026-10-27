part of 'messaging_conversation_actions_sheet.dart';

/// Superficie Material del menú. Solo las acciones frecuentes quedan expuestas.
/// ExpansionTile administra y libera su animación; no se crean controladores propios.
class _ConversationActionsMenu extends StatelessWidget {
  const _ConversationActionsMenu({
    required this.item,
    required this.active,
    required this.archived,
    required this.agent,
    required this.target,
    required this.blur,
  });
  final ConversationSummaryItem item;
  final bool active, archived;
  final ConversationAgentId agent, target;
  final double blur;

  // Limita por ventana y permite scroll: teclado, horizontal y texto ampliado.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Material(
      color: scheme.surface.withValues(alpha: blur > 0 ? 0.93 : 1),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Cerrar opciones',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            _action(
              context,
              active
                  ? Icons.pause_circle_outline_rounded
                  : Icons.smart_toy_rounded,
              active ? 'Pausar Nano en este chat' : 'Activar Nano en este chat',
              active
                  ? 'El control queda en tus manos.'
                  : 'Habilita la regla y el agente asignado.',
              _ConversationAction.toggleBot,
            ),
            _action(
              context,
              archived ? Icons.unarchive_rounded : Icons.archive_rounded,
              archived ? 'Desarchivar en Nano' : 'Archivar en Nano',
              'Solo organiza la lista local.',
              archived
                  ? _ConversationAction.unarchive
                  : _ConversationAction.archive,
            ),
            ExpansionTile(
              title: const Text('Opciones avanzadas'),
              subtitle: const Text('Agente y datos locales'),
              expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                  ? AnimationStyle.noAnimation
                  : null,
              children: [
                _action(
                  context,
                  Icons.swap_horiz_rounded,
                  'Agente: ${agent.displayName}',
                  'Cambiar a ${target.displayName}',
                  _ConversationAction.transferAgent,
                ),
                _action(
                  context,
                  Icons.cleaning_services_rounded,
                  'Limpiar memoria de Nano',
                  'Pausa el agente y borra su contexto local.',
                  _ConversationAction.clearMemory,
                ),
                _action(
                  context,
                  Icons.delete_outline_rounded,
                  'Quitar del centro de Nano',
                  'Pausa y oculta este chat. No borra WhatsApp.',
                  _ConversationAction.remove,
                  destructive: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        MediaQuery.viewInsetsOf(context).bottom + 8,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: blur == 0
                ? content
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }

  // ListTile hereda tipografía y objetivos táctiles Material, sin alturas rígidas.
  Widget _action(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    _ConversationAction action, {
    bool destructive = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: destructive ? scheme.error : scheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
