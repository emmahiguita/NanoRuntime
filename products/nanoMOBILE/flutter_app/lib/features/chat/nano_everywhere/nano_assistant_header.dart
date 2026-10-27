import 'package:flutter/material.dart';
import 'nano_ai_models.dart';
import 'nano_owl_3d_turntable.dart';

/// Cabecera compacta. Reutiliza el personaje animado y separa historial de
/// contraer: cerrar la ventana no promete detener una tarea en ejecución.
class NanoAssistantHeader extends StatelessWidget {
  const NanoAssistantHeader({
    super.key,
    required this.onClose,
    required this.onHistory,
    this.onExpand,
    this.compact = false,
    this.activity = NanoActivity.idle,
  });
  final VoidCallback onClose, onHistory;
  final VoidCallback? onExpand;
  final bool compact;
  final NanoActivity activity;

  /// El avatar conserva su interacción y ofrece la navegación ya existente.
  /// Elimina la flecha que sugería ampliar esta misma conversación.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Tooltip(
          message: 'Abrir módulo de Nano',
          child: NanoOwl3dTurntable(
            size: compact ? 38 : 44,
            activity: activity,
            interactive: true,
            onTap: onExpand,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Búho AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Asistente de Nano',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Historial de acciones',
          onPressed: onHistory,
          icon: const Icon(Icons.history_rounded, size: 21),
          color: colors.onSurfaceVariant,
        ),
        IconButton(
          tooltip: 'Contraer panel',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 21),
          color: colors.onSurfaceVariant,
        ),
      ],
    );
  }
}
