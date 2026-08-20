import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/app_providers.dart';

import 'package:nanoai/features/home/nano_home_screen.dart';
import 'package:nanoai/features/home/nano_home_models.dart';

// ════════════════════════════════════════════════════════════════════
// Conexión con Riverpod y las rutas para la nueva Home (Glass)
// ════════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  KaliStatus _mapKaliStatus(bool isInstalled) {
    if (!isInstalled) return KaliStatus.notInitialized;
    // Por simplicidad, mapeamos isInstalled a running, pero idealmente
    // se usaría el estado real del servicio Kali.
    return KaliStatus.running;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final rootfs = ref.watch(rootfsProvider);
    final chat = ref.watch(chatProvider);

    final chatSubtitle = chat.engineOnline
        ? null
        : 'Motor apagado — elige modelo';
    final terminalSubtitle = rootfs.isInstalled
        ? 'Linux listo'
        : 'Preparando Linux';

    return NanoHomeScreen(
      telemetry: NanoTelemetryData(
        ram: dashboard.ramTotalGb > 0
            ? '${dashboard.ramFreeGb.toStringAsFixed(1)} GB'
            : '—',
        cpu: dashboard.cpuCores > 0 ? '${dashboard.cpuCores}' : '—',
        temperature: dashboard.tempC > 0
            ? '${dashboard.tempC.round()} °C'
            : '—',
        freeStorage: dashboard.storageTotalGb > 0
            ? '${dashboard.storageFreeGb.round()} GB'
            : '—',
        battery: dashboard.batteryPct >= 0
            ? '${dashboard.batteryPct.round()}%'
            : '—',
      ),
      kaliStatus: _mapKaliStatus(rootfs.isInstalled),
      chatSubtitle: chatSubtitle,
      terminalSubtitle: terminalSubtitle,
      onTerminalTap: () => context.go('/terminal'),
      onChatTap: () => context.go('/chat'),
      onModelsTap: () => context.go('/models'),
      onDesktopTap: () => context.go('/desktop'),
    onAutomationTap: () => context.go('/automation'),
      onKaliTap: () => context.go('/terminal/shell?cmd=kali%20shell'),
    );
  }
}
