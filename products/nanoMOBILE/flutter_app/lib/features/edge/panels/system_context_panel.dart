/// EDGE-03 — Panel de sistema: aplica a Ajustes y superficies del sistema.
/// Muestra el estado del dispositivo observado (batería, RAM, storage).
/// Puro: solo [NanoEdgeState].
library;

import '../nano_edge_state.dart';
import 'context_panel.dart';

const _systemPackages = <String>{
  'com.android.settings',
  'com.android.systemui',
  'com.android.phone',
  'com.coloros.settings',
};

final class SystemContextPanel implements ContextPanel {
  const SystemContextPanel();

  @override
  String get id => 'system';

  @override
  bool matches(String packageName) => _systemPackages.contains(packageName);

  @override
  NanoEdgeContent contentFor(NanoEdgeState state) {
    final device = state.snapshot?.deviceState;
    final lines = <String>[
      if (device != null)
        'Batería: ${_pct(device.batteryPct)}'
            '${device.isCharging == true ? ' (cargando)' : ''}',
      if (device != null && device.ramAvailableMb != null)
        'RAM libre: ${device.ramAvailableMb!.round()} MB',
      if (device != null && device.storageFreeGb != null)
        'Storage libre: ${device.storageFreeGb!.toStringAsFixed(1)} GB',
      if (device != null && device.cpuTempC != null)
        'CPU: ${device.cpuTempC!.toStringAsFixed(0)} °C',
    ];
    return NanoEdgeContent(
      title: 'Sistema',
      body: lines.isEmpty ? 'Métricas no disponibles.' : lines.join('\n'),
    );
  }

  static String _pct(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(0)}%';
}
