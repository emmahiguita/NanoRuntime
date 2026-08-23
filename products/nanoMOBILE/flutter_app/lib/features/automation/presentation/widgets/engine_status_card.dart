import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import 'automation_dashboard.dart' show engineStatusProvider;

/// Card de estado del motor (runtime/modelo/fase) — COMPARTIDA, una sola fuente.
/// Usada por el dashboard y la pantalla Dev (sin duplicación).
class EngineStatusCard extends ConsumerWidget {
  const EngineStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final engine = ref.watch(engineStatusProvider);
    return NanoCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Estado', Icons.monitor_heart_rounded, colors: colors),
            const SizedBox(height: NanoSpacing.xs),
            _row(context, 'Agente', engine?.isLive ?? false),
            _row(context, 'Runtime', engine?.phase.name ?? '—'),
            _row(context, 'Modelo', engine?.modelPath?.split('/').last ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, dynamic value) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
