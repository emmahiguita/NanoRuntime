/// AUTOMATION-ACTIVE-CARD — Visualización de la tarea activa y veredictos.
///
/// QUÉ HACE:
/// Muestra el objetivo en curso o el resultado de la última automatización ejecutada.
///
/// CÓMO FUNCIONA:
/// Emplea animación pulsante durante ejecución y distinción cromática honesta
/// entre tareas verificadas vs completadas sin verificar.
///
/// POR QUÉ:
/// Ofrece transparencia y certeza sobre lo que Nano acaba de hacer en el móvil.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_motion.dart';
import '../../../../core/theme/nano_type.dart';
import '../../domain/automation_result.dart';
import '../automation_visual_theme.dart';

class ActiveExecutionCard extends StatefulWidget {
  const ActiveExecutionCard({
    super.key,
    required this.goal,
    required this.running,
    required this.status,
    required this.reason,
    this.onConfirm,
  });

  final String goal;
  final bool running;
  final AutomationResultStatus? status;
  final String reason;
  final VoidCallback? onConfirm;

  @override
  State<ActiveExecutionCard> createState() => _ActiveExecutionCardState();
}

class _ActiveExecutionCardState extends State<ActiveExecutionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.running) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ActiveExecutionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running && !oldWidget.running) {
      _pulse.repeat(reverse: true);
    } else if (!widget.running && oldWidget.running) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  ({IconData icon, Color color, String label}) _statusPresentation(
    AutomationResultStatus s,
    NanoColors colors,
  ) {
    switch (s) {
      case AutomationResultStatus.completed:
        return (icon: Icons.check_circle_rounded, color: colors.success, label: 'Verificado');
      case AutomationResultStatus.completedUnverified:
        return (icon: Icons.report_problem_rounded, color: colors.warning, label: 'Completado sin verificar');
      case AutomationResultStatus.paused:
        return (icon: Icons.pause_circle_outline_rounded, color: colors.warning, label: 'Esperando confirmación');
      case AutomationResultStatus.denied:
        return (icon: Icons.block_rounded, color: colors.warning, label: 'Denegado por política');
      case AutomationResultStatus.noPlan:
        return (icon: Icons.error_outline_rounded, color: colors.warning, label: 'Sin plan');
      case AutomationResultStatus.failed:
        return (icon: Icons.cancel_rounded, color: colors.error, label: 'No completado');
      case AutomationResultStatus.outcomeUnknown:
        return (icon: Icons.help_outline_rounded, color: colors.warning, label: 'Resultado desconocido');
      case AutomationResultStatus.cancelled:
        return (icon: Icons.not_interested_rounded, color: colors.onSurfaceVariant, label: 'Cancelado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final done = !widget.running && widget.status != null;
    final present = done ? _statusPresentation(widget.status!, colors) : null;
    final activeColor = present?.color ?? AutomationVisual.of(context).accent;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: widget.running
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.10 + _pulse.value * 0.18),
                    blurRadius: 14 + _pulse.value * 14,
                    spreadRadius: _pulse.value * 1.5,
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
      child: AutomationSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: activeColor.withValues(alpha: 0.35), width: 1),
                    boxShadow: [
                      BoxShadow(color: activeColor.withValues(alpha: 0.20), blurRadius: 8),
                    ],
                  ),
                  child: Icon(present?.icon ?? Icons.auto_awesome_rounded, color: activeColor, size: 18),
                ),
                const SizedBox(width: NanoSpacing.sm),
                Expanded(
                  child: Text(
                    widget.goal,
                    maxLines: 4,
                    style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NanoSpacing.sm),
            AnimatedSwitcher(
              duration: NanoMotionDurations.quick,
              child: Text(
                widget.running ? 'Ejecutando en el dispositivo…' : (present?.label ?? ''),
                key: ValueKey('${widget.running}-${widget.status}'),
                style: NanoType.label(present?.color ?? colors.onSurfaceVariant),
              ),
            ),
            if (!widget.running && widget.reason.trim().isNotEmpty) ...[
              const SizedBox(height: NanoSpacing.xs),
              Text(
                widget.reason.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: NanoType.caption(colors.onSurfaceVariant),
              ),
            ],
            if (widget.onConfirm != null) ...[
              const SizedBox(height: NanoSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: widget.onConfirm,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Confirmar y continuar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
