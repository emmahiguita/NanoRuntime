import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'llm_engine_client.dart';
import 'runtime_engine.dart';

/// Telemetría REAL del runtime, polleada de forma independiente.
///
/// A diferencia del [DashboardNotifier] (que pollea métricas del device vía
/// canal cada 3s), este notifier pollea GET /api/status (HTTP localhost)
/// solo cuando el motor está vivo, con un intervalo propio. Así el health
/// monitor se actualiza sin forzar rebuild de TODO el dashboard.
class RuntimeTelemetryNotifier extends StateNotifier<RuntimeStatus?> {
  final Ref _ref;
  Timer? _timer;

  /// Poll menos agresivo que el dashboard: la telemetría cambia despacio
  /// (fault_rate/PSS/thrashing no oscilan a nivel de segundos).
  static const Duration interval = Duration(seconds: 5);

  RuntimeTelemetryNotifier(this._ref) : super(null) {
    _ref.listen<EngineStatus>(runtimeEngineProvider, (_, next) {
      _onEngineChanged(next);
    });
    _onEngineChanged(_ref.read(runtimeEngineProvider));
  }

  void _onEngineChanged(EngineStatus engine) {
    if (engine.isLive) {
      if (_timer == null) {
        _poll();
        _timer = Timer.periodic(interval, (_) => _poll());
      }
    } else {
      _timer?.cancel();
      _timer = null;
      state = null;
    }
  }

  Future<void> _poll() async {
    try {
      final status = await _ref
          .read(runtimeEngineProvider.notifier)
          .client
          .getStatus();
      if (mounted) state = status;
    } catch (_) {
      // Motor cayó entre polls: se mantiene el último snapshot hasta que
      // EngineStatus marque idle/failed (que lo limpia a null).
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final runtimeTelemetryProvider =
    StateNotifierProvider<RuntimeTelemetryNotifier, RuntimeStatus?>(
      (ref) => RuntimeTelemetryNotifier(ref),
    );
