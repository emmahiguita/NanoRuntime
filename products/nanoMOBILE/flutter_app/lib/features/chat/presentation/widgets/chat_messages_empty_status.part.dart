part of 'chat_messages.dart';

// QUÉ HACE: Muestra el estado real del motor o el acceso a modelos desde el chat vacío.
// CÓMO FUNCIONA: Presenta estados distintos para motor apagado, sin modelo y listo.
// POR QUÉ: Informa sin usar la franja amarilla ni simular disponibilidad.
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
    final scheme = Theme.of(context).colorScheme;
    if (!engineOnline) {
      return _EmptyChatStatusCard(
        icon: Icons.power_settings_new_rounded,
        title: 'Motor local no iniciado',
        actionLabel: 'Iniciar Motor Local',
        onPressed: onRetry,
        color: scheme.onSurfaceVariant,
      );
    }
    if (!hasModel) {
      return _EmptyChatStatusCard(
        icon: Icons.inventory_2_outlined,
        title: 'No hay modelo cargado en memoria',
        actionLabel: 'Seleccionar o Descargar Modelo',
        onPressed: onGoModels,
        color: scheme.primary,
        isPrimary: true,
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 7, color: scheme.tertiary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'Motor listo · Ejecución local y Memento CBR activos',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
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

// QUÉ HACE: Presenta acciones de estado en una tarjeta compacta y accesible.
class _EmptyChatStatusCard extends StatelessWidget {
  const _EmptyChatStatusCard({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onPressed,
    required this.color,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onPressed;
  final Color color;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC0E1726) : const Color(0xF5F8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isPrimary)
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
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
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
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
