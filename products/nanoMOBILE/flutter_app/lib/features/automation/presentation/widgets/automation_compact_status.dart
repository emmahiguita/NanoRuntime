import 'package:flutter/material.dart';
import '../../../../core/widgets/nano_anchored_popover.dart';
import '../../domain/automation_result.dart';

/// Resumen compacto de WhatsApp. El resultado del motor se muestra sin cambiar
/// su veredicto: ejecutar un clic no se convierte en confirmación de entrega.
class AutomationCompactStatus extends StatelessWidget {
  const AutomationCompactStatus({
    super.key,
    required this.goal,
    required this.running,
    required this.status,
    required this.reason,
    this.onConfirm,
  });
  final String goal, reason;
  final bool running;
  final AutomationResultStatus? status;
  final VoidCallback? onConfirm;

  String get _label => running
      ? 'Ejecutando en WhatsApp…'
      : switch (status) {
          AutomationResultStatus.completed => 'Acción completada',
          AutomationResultStatus.completedUnverified => 'Entrega sin confirmar',
          AutomationResultStatus.paused => 'Requiere confirmación',
          AutomationResultStatus.cancelled => 'Cancelado',
          AutomationResultStatus.outcomeUnknown => 'Resultado incierto',
          AutomationResultStatus.denied => 'Acción no autorizada',
          _ => 'No completado',
        };

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      dense: true,
      minTileHeight: 48,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: running && !MediaQuery.disableAnimationsOf(context)
          ? const RepaintBoundary(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Icon(
              running
                  ? Icons.hourglass_top_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      title: Text(_label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: running
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 18),
      // Durante la ejecución no se abre una copia estática de un estado cambiante.
      onTap: running
          ? null
          : () => showNanoAnchoredPopover<void>(
              anchorContext: context,
              label: 'Resultado de WhatsApp',
              builder: (menu) => SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_label, style: Theme.of(menu).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(reason.isEmpty ? goal : reason),
                    if (status == AutomationResultStatus.paused &&
                        onConfirm != null)
                      TextButton(
                        onPressed: () {
                          Navigator.of(menu).pop();
                          onConfirm!();
                        },
                        child: const Text('Confirmar'),
                      ),
                  ],
                ),
              ),
            ),
    ),
  );
}
