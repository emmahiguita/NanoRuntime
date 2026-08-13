import 'nano_runtime_api.dart';

/// Real hardware metrics from Android via NanoRuntimeApi.
/// Falls back to safe defaults if runtime unavailable.
class DeviceMetrics {
  static bool _available = true;

  /// One-shot fetch of all device metrics.
  static Future<DeviceMetricsData> fetch() async {
    if (!_available) return DeviceMetricsData.fallback();
    try {
      final raw = await NanoRuntimeApi.instance.getMetrics();
      if (raw == null) {
        _available = false;
        return DeviceMetricsData.fallback();
      }
      final m = raw.map((k, v) => MapEntry(k.toString(), v));
      return DeviceMetricsData(
        ramAvailableMb: (m['ramAvailableMb'] as num?)?.toDouble() ?? 0,
        ramTotalMb: (m['ramTotalMb'] as num?)?.toDouble() ?? 0,
        batteryPct: (m['batteryPct'] as num?)?.toDouble() ?? -1,
        isCharging: m['isCharging'] as bool? ?? false,
        storageTotalGb: (m['storageTotalGb'] as num?)?.toDouble() ?? 0,
        storageFreeGb: (m['storageFreeGb'] as num?)?.toDouble() ?? 0,
        cpuTempC: (m['cpuTempC'] as num?)?.toDouble(),
        cpuCores: (m['cpuCores'] as int?) ?? 0,
      );
    } catch (_) {
      return DeviceMetricsData.fallback();
    }
  }
}

class DeviceMetricsData {
  final double ramAvailableMb, ramTotalMb, storageTotalGb, storageFreeGb;
  final double batteryPct;
  final bool isCharging;
  final double? cpuTempC;
  final int cpuCores;

  const DeviceMetricsData({
    required this.ramAvailableMb,
    required this.ramTotalMb,
    required this.batteryPct,
    required this.isCharging,
    required this.storageTotalGb,
    required this.storageFreeGb,
    this.cpuTempC,
    required this.cpuCores,
  });

  factory DeviceMetricsData.fallback() => const DeviceMetricsData(
    ramAvailableMb: 0, ramTotalMb: 0, batteryPct: -1,
    isCharging: false, storageTotalGb: 0, storageFreeGb: 0,
    cpuTempC: null, cpuCores: 0,
  );

  // Convenience getters
  double get ramAvailableGb => ramAvailableMb / 1024.0;
  double get ramTotalGb => ramTotalMb / 1024.0;
  double get ramUsedGb => ramTotalGb - ramAvailableGb;
  double get ramProgress => ramTotalGb > 0 ? ramUsedGb / ramTotalGb : 0;
  double get storageUsedGb => storageTotalGb - storageFreeGb;
  double get storageProgress => storageTotalGb > 0 ? storageUsedGb / storageTotalGb : 0;
}
