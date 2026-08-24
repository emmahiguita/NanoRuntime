import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import 'automation_dashboard.dart' show engineStatusProvider;
import 'interactive_glass_card.dart';

/// Card de estado del motor (runtime/modelo/fase) — COMPARTIDA, una sola fuente.
/// Usada por el dashboard y la pantalla Dev (sin duplicación).
class EngineStatusCard extends ConsumerWidget {
  const EngineStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    // Lee el ENDPOINT real (no el notifier) → refleja el motor que responderá.
    final engine = ref.watch(engineStatusProvider).valueOrNull;
    return InteractiveGlassCard(
      borderStrength: 0.45,
      reflectionStrength: 0.3,
      blurSigma: 12,
      glassOpacityScale: 0.78,
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Estado', Icons.monitor_heart_rounded, colors: colors),
            const SizedBox(height: NanoSpacing.xs),
            // Compacta en 3 mini-columnas → aprovecha el ancho (no 3 filas
            // gigantes). Los valores se leen de lado a lado.
            Row(
              children: [
                _stat(context, colors, 'Agente', engine?.isLive ?? false),
                _stat(context, colors, 'Runtime', engine?.phase.name ?? '—'),
                _stat(context, colors, 'Modelo',
                    engine?.modelPath?.split('/').last ?? '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    dynamic colors,
    String label,
    dynamic value,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NanoType.caption(colors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NanoType.body(colors.textPrimary).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
