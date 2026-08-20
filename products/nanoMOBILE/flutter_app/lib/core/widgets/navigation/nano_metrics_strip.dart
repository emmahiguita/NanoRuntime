import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/design_tokens.dart';

/// Tira compacta de telemetría de hardware conectada al dashboardProvider en tiempo real.
class NanoMetricsStrip extends ConsumerWidget {
  const NanoMetricsStrip({
    super.key,
    required this.colors,
    this.compact = false,
  });

  final NanoColors colors;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) return const SizedBox.shrink();

    final dash = ref.watch(dashboardProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dash.batteryPct >= 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _metricChip(
              Icons.battery_full_rounded,
              '${dash.batteryPct.toInt()}%',
              dash.batteryPct < 20 ? colors.warning : colors.success,
            ),
          ),
          const SizedBox(height: 7),
        ],
        if (dash.tempC > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _metricChip(
              Icons.thermostat_rounded,
              '${dash.tempC.toStringAsFixed(0)} °C',
              dash.tempC > 45 ? colors.error : colors.info,
            ),
          ),
          const SizedBox(height: 7),
        ],
        if (dash.ramTotalGb > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _metricChip(
              Icons.memory_rounded,
              '${dash.ramTotalGb.toStringAsFixed(1)} GB',
              colors.primary,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _metricChip(IconData icon, String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: NanoShapes.full,
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
