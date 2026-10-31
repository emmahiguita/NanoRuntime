part of 'chat_messages.dart';

// chat_messages_empty_status.part.dart — Estado del motor local en chat vacío con Liquid Glass.
// QUÉ HACE: Muestra el estado del motor o acceso a modelos cuando el chat no tiene mensajes.
// CÓMO FUNCIONA: Usa tarjetas Liquid Glass, CupertinoIcons y paleta del tema sin franjas toscas.
// POR QUÉ: Sustituye contenedores opacos y botones genéricos por diseño limpio iOS (< 160 líneas).

class _EmptyChatEngineStatus extends StatelessWidget {
  const _EmptyChatEngineStatus({
    required this.engineOnline,
    required this.hasModel,
    required this.onRetry,
    required this.onGoModels,
    required this.onSuggestion,
  });

  final bool engineOnline;
  final bool hasModel;
  final VoidCallback onRetry;
  final VoidCallback onGoModels;
  final void Function(String) onSuggestion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    if (!engineOnline) {
      return _EmptyChatStatusCard(
        icon: CupertinoIcons.power,
        title: 'Motor local no iniciado',
        actionLabel: 'Iniciar Motor Local',
        onPressed: onRetry,
        color: colors.onSurfaceVariant,
        colors: colors,
      );
    }
    if (!hasModel) {
      return _EmptyChatStatusCard(
        icon: CupertinoIcons.cube_box,
        title: 'No hay modelo cargado en memoria',
        actionLabel: 'Seleccionar o Descargar Modelo',
        onPressed: onGoModels,
        color: colors.primary,
        isPrimary: true,
        colors: colors,
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.circle_fill, size: 7, color: colors.accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'Motor listo · Ejecución local y Memento CBR activos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _EmptyChatQuickActionGrid(onSuggestion: onSuggestion),
      ],
    );
  }
}

class _EmptyChatStatusCard extends StatelessWidget {
  const _EmptyChatStatusCard({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onPressed,
    required this.color,
    required this.colors,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onPressed;
  final Color color;
  final NanoColors colors;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: isDark ? 0.35 : 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.18),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(icon, size: 14, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPrimary)
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 15),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              key: const ValueKey('chat_retry_button'),
              onPressed: onPressed,
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 15),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
                side: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}