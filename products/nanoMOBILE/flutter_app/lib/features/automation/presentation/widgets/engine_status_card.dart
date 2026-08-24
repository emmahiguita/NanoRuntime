import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/rootfs_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import 'automation_dashboard.dart' show engineStatusProvider;

/// Card de estado EN VIVO (motor/modelo/Linux) — COMPARTIDA. Lee el endpoint
/// REAL. Capacidades en lenguaje humano (nunca `true/false` ni `phase.name`),
/// y los detalles técnicos se revelan al tocar (no saturan la vista).
class EngineStatusCard extends ConsumerWidget {
  const EngineStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final engine = ref.watch(engineStatusProvider).valueOrNull;
    final linux = ref.watch(rootfsProvider).isInstalled;
    final ready = engine?.phase == EnginePhase.ready;
    final hasModel = engine?.modelPath != null;

    return NanoOpticalSurface(
      borderStrength: 0.45,
      reflectionStrength: 0.28,
      blurSigma: 12,
      padding: const EdgeInsets.all(NanoSpacing.md),
      onTap: () => _showDetails(context, engine, linux),
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

  void _showDetails(BuildContext context, EngineStatus? engine, bool linux) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colors = NanoThemeExtension.of(ctx).colors;
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
              ],
            ),
          ),
        );
      },
    );
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
