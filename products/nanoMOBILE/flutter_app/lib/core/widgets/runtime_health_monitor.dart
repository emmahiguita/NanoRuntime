import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/services/runtime_telemetry.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Health monitor compacto del runtime — telemetría REAL (fault_rate/PSS/
/// thrashing/W/tok-s/tier) vía el poll del dashboard (item 11 del plan V1).
///
/// Nada simulado: el [DashboardState.telemetry] viene de GET /api/status
/// contra el motor nanortime real. Sin motor vivo → estado apagado honesto.
class RuntimeHealthMonitor extends ConsumerWidget {
  const RuntimeHealthMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(runtimeTelemetryProvider);
    final enginePhase = ref.watch(runtimeEngineProvider).phase;
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;

    final String title;
    final String subtitle;
    final Color accent;
    final IconData icon;

    if (telemetry == null) {
      final idle = enginePhase == EnginePhase.idle;
      title = idle ? 'Local AI apagado' : 'Consultando…';
      subtitle = idle ? 'Motor sin arrancar' : 'Esperando telemetría del runtime';
      accent = idle
          ? colors.onSurface.withValues(alpha: 0.5)
          : colors.accent;
      icon = idle ? Icons.power_off_rounded : Icons.hourglass_empty_rounded;
    } else {
      final t = telemetry;
      final tier = t.viability?.tier ?? 'LOCAL';
      final pss = t.pssMb != null
          ? '${t.pssMb!.toStringAsFixed(0)} MB'
          : '${t.modelSizeMb} MB';
      final thrashing = t.thrashing;
      accent = thrashing ? colors.danger : colors.success;
      icon = thrashing
          ? Icons.warning_amber_rounded
          : Icons.memory_rounded;
      title = thrashing ? '$tier · THRASHING' : tier;
      subtitle = thrashing
          ? 'fault ${t.faultRate.toStringAsFixed(0)}/s · W=${t.residentWindow}'
          : 'W=${t.residentWindow} · $pss · ${t.tokS.toStringAsFixed(2)} tok/s';
    }

    return Semantics(
      label: 'Runtime: $title. $subtitle',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
