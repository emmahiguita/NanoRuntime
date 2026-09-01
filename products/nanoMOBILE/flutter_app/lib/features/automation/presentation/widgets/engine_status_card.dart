import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/rootfs_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import '../automation_visual_theme.dart';
import 'automation_dashboard.dart' show engineStatusProvider;

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
                      const Text(
                        'ESTADO DEL SISTEMA',
                        style: TextStyle(
                          color: AutomationVisual.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
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

  void _showDetails(
    BuildContext context,
    EngineStatus? engine,
    bool linux,
    WidgetRef ref,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colors = NanoThemeExtension.of(ctx).colors;
        final live = engine?.isLive ?? false;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              NanoSpacing.lg,
              0,
              NanoSpacing.lg,
              NanoSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  'Detalles del runtime',
                  Icons.terminal_rounded,
                  colors: colors,
                ),
                const SizedBox(height: NanoSpacing.sm),
                _detailRow(ctx, 'Fase', engine?.phase.name ?? '—'),
                _detailRow(
                  ctx,
                  'Modelo',
                  engine?.modelPath?.split('/').last ?? '—',
                ),
                _detailRow(ctx, 'Puerto', '${engine?.port ?? 0}'),
                _detailRow(ctx, 'Linux', linux ? 'Instalado' : 'Sin preparar'),
                const SizedBox(height: NanoSpacing.md),
                // Control de ciclo de vida del motor. El «Reiniciar» (stop+start)
                // libera el puerto si quedó ocupado por un motor colgado.
                Wrap(
                  spacing: NanoSpacing.sm,
                  runSpacing: NanoSpacing.sm,
                  children: [
                    if (live)
                      FilledButton.icon(
                        onPressed: () =>
                            ref.read(runtimeEngineProvider.notifier).stop(),
                        icon: const Icon(Icons.power_settings_new_rounded),
                        label: const Text('Apagar'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () =>
                            ref.read(runtimeEngineProvider.notifier).start(),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Encender'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _restart(ref),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reiniciar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Reinicio seguro: detener el motor (libera el puerto) y arrancar de nuevo.
  /// Útil cuando el puerto aparece ocupado por un proceso del motor colgado.
  Future<void> _restart(WidgetRef ref) async {
    final notifier = ref.read(runtimeEngineProvider.notifier);
    await notifier.stop();
    await notifier.start();
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: NanoType.label(colors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NanoType.body(colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanCapabilityRow extends StatelessWidget {
  const _CleanCapabilityRow({
    required this.ok,
    required this.okText,
    required this.offText,
  });

  final bool ok;
  final String okText;
  final String offText;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF24B47E) : AutomationVisual.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ok ? okText : offText,
              style: const TextStyle(
                color: AutomationVisual.text,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemReadyMark extends StatelessWidget {
  const _SystemReadyMark({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF24B47E) : AutomationVisual.accent;
    return SizedBox.square(
      dimension: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ready ? Icons.check_rounded : Icons.pause_rounded,
              color: color,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de capacidad con estado humano + dot de color (nunca true/false).
class _CapabilityRow extends StatelessWidget {
  final bool ok;
  final String okText;
  final String offText;
  final NanoColors colors;

  const _CapabilityRow({
    required this.ok,
    required this.okText,
    required this.offText,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? colors.success : colors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 5),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            ok ? okText : offText,
            style: NanoType.body(ok ? colors.onSurface : color),
          ),
        ],
      ),
    );
  }
}
