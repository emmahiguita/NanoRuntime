import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/rootfs_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import '../automation_visual_theme.dart';
import 'automation_dashboard.dart' show engineStatusProvider;

part 'engine_status_card_details.part.dart';
part 'engine_status_card_rows.part.dart';
part 'engine_status_ready_mark.part.dart';

/// Card de estado EN VIVO (motor/modelo/Linux) — COMPARTIDA. Lee el endpoint
/// REAL. Capacidades en lenguaje humano (nunca `true/false` ni `phase.name`),
/// y los detalles técnicos se revelan al tocar (no saturan la vista).
class EngineStatusCard extends ConsumerWidget {
  const EngineStatusCard({super.key, this.cleanAppearance = false});

  final bool cleanAppearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final engine = ref.watch(engineStatusProvider).valueOrNull;
    final linux = ref.watch(rootfsProvider).isInstalled;
    final ready = engine?.phase == EnginePhase.ready;
    final hasModel = engine?.modelPath != null;

    if (cleanAppearance) {
      return AutomationSurfaceCard(
        onTap: () => _showDetails(context, engine, linux, ref),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showMark = constraints.maxWidth >= 280;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESTADO DEL SISTEMA',
                        style: TextStyle(
                          color: AutomationVisual.of(context).isDark
                              ? Colors.white.withValues(alpha: 0.90)
                              : AutomationVisual.of(context).textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          shadows: AutomationVisual.of(context).isDark
                              ? const [
                                  Shadow(
                                    color: Color(0x70000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CleanCapabilityRow(
                        ok: ready,
                        okText: 'Agente listo',
                        offText: 'Motor detenido',
                      ),
                      _CleanCapabilityRow(
                        ok: hasModel,
                        okText: 'Modelo cargado',
                        offText: 'Modelo no cargado',
                      ),
                      _CleanCapabilityRow(
                        ok: linux,
                        okText: 'Linux disponible',
                        offText: 'Linux sin preparar',
                      ),
                    ],
                  ),
                ),
                if (showMark) ...[
                  const SizedBox(width: 14),
                  _SystemReadyMark(ready: ready),
                ],
              ],
            );
          },
        ),
      );
    }

    return NanoOpticalSurface(
      borderStrength: 0.45,
      reflectionStrength: 0.28,
      blurSigma: 12,
      padding: const EdgeInsets.all(NanoSpacing.md),
      onTap: () => _showDetails(context, engine, linux, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Estado', Icons.monitor_heart_rounded, colors: colors),
          const SizedBox(height: NanoSpacing.xs),
          _CapabilityRow(
            ok: ready,
            okText: 'Agente listo',
            offText: 'Motor detenido',
            colors: colors,
          ),
          _CapabilityRow(
            ok: hasModel,
            okText: 'Modelo cargado',
            offText: 'Modelo no cargado',
            colors: colors,
          ),
          _CapabilityRow(
            ok: linux,
            okText: 'Linux disponible',
            offText: 'Linux sin preparar',
            colors: colors,
          ),
          const SizedBox(height: NanoSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Toca para detalles',
              style: NanoType.caption(colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
