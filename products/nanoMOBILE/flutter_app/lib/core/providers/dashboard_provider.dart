import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/device_metrics.dart';
import '../services/runtime_engine.dart';
import '../services/llm_engine_client.dart';
import 'chat_provider.dart';

// ================================================================
// Dashboard State
// ================================================================

class DashboardState {
  final double ramFreeGb,
      ramTotalGb,
      ramProgress,
      tempC,
      tempProgress,
      batteryPct,
      tpsValue,
      tpsProgress;
  final double storageTotalGb, storageFreeGb, storageProgress;
  final bool isCharging;
  final int cpuCores;
  final bool isLive; // true = connected to real device
  final EnginePhase enginePhase; // fase real del motor nanortime
  /// Telemetría REAL del runtime (fault_rate/PSS/thrashing/W/tier) vía
  /// /api/status. Null cuando el motor no está vivo o el poll aún no respondió.
  final RuntimeStatus? telemetry;

  const DashboardState({
    this.ramFreeGb = 0,
    this.ramTotalGb = 0,
    this.ramProgress = 0,
    this.tempC = 0,
    this.tempProgress = 0,
    this.batteryPct = -1,
    this.tpsValue = 0,
    this.tpsProgress = 0,
    this.storageTotalGb = 0,
    this.storageFreeGb = 0,
    this.storageProgress = 0,
    this.isCharging = false,
    this.cpuCores = 0,
    this.isLive = false,
    this.enginePhase = EnginePhase.idle,
    this.telemetry,
  });

  /// Value equality: prevents StateNotifier from notifying watchers when
  /// polled metrics haven't actually changed.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardState &&
          ramFreeGb == other.ramFreeGb &&
          ramTotalGb == other.ramTotalGb &&
          ramProgress == other.ramProgress &&
          tempC == other.tempC &&
          tempProgress == other.tempProgress &&
          batteryPct == other.batteryPct &&
          tpsValue == other.tpsValue &&
          tpsProgress == other.tpsProgress &&
          storageTotalGb == other.storageTotalGb &&
          storageFreeGb == other.storageFreeGb &&
          storageProgress == other.storageProgress &&
          isCharging == other.isCharging &&
          cpuCores == other.cpuCores &&
          isLive == other.isLive &&
          enginePhase == other.enginePhase &&
          telemetry == other.telemetry;

  @override
  int get hashCode => Object.hash(
    ramFreeGb,
    ramTotalGb,
    ramProgress,
    tempC,
    tempProgress,
    batteryPct,
    tpsValue,
    tpsProgress,
    storageTotalGb,
    storageFreeGb,
    storageProgress,
    isCharging,
    cpuCores,
    isLive,
    enginePhase,
    telemetry,
  );
}

// ================================================================
// Dashboard Notifier
// ================================================================

class DashboardNotifier extends StateNotifier<DashboardState> {
  Timer? _timer;
  final Ref _ref;

  DashboardNotifier(this._ref) : super(const DashboardState()) {
    _startPolling();
  }

  /// Test-only: emits a fixed state without timers or IO.
  @visibleForTesting
  DashboardNotifier.fixed(Ref ref, super.initial) : _ref = ref;

  void _startPolling() {
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    final d = await DeviceMetrics.fetch();
    // TPS real del motor: lo reporta ChatNotifier tras cada generación.
    final liveTps = _ref.read(chatProvider).liveTps;
    // Fase real del motor: la posee RuntimeEngineNotifier (único dueño).
    final engine = _ref.read(runtimeEngineProvider);
    final enginePhase = engine.phase;
    // Telemetría REAL del runtime vía /api/status — solo con motor vivo.
    RuntimeStatus? telemetry;
    if (engine.isLive) {
      try {
        telemetry = await _ref
            .read(runtimeEngineProvider.notifier)
            .client
            .getStatus();
      } catch (_) {
        // El motor cayó entre el check de fase y el poll: mantener null.
      }
    }
    state = DashboardState(
      ramFreeGb: d.ramAvailableGb,
      ramTotalGb: d.ramTotalGb,
      ramProgress: d.ramProgress,
      tempC: d.cpuTempC ?? 0,
      tempProgress: d.cpuTempC != null ? d.cpuTempC! / 90.0 : 0,
      batteryPct: d.batteryPct,
      isCharging: d.isCharging,
      tpsValue: liveTps ?? 0,
      tpsProgress: liveTps != null ? (liveTps / 40.0).clamp(0.0, 1.0) : 0,
      storageTotalGb: d.storageTotalGb,
      storageFreeGb: d.storageFreeGb,
      storageProgress: d.storageProgress,
      cpuCores: d.cpuCores,
      isLive: d.ramTotalMb > 0,
      enginePhase: enginePhase,
      telemetry: telemetry,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
      (ref) => DashboardNotifier(ref),
    );
