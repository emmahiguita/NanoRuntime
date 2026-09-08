/// TimeTickScheduler (TRIG-01) — productor REAL de [TickEvent].
///
/// REVIEW-01 P3d: TimeTrigger existía sin productor — las reglas de hora
/// jamás disparaban. Este scheduler emite un tick cuando cambia el minuto
/// del reloj y alimenta el mismo RulePipeline que las notificaciones.
///
/// Alcance honesto: corre EN la app (Timer periódico). Si ColorOS mata el
/// proceso, no hay tick — el scheduler de sistema (AlarmManager) es otra
/// iteración. La UI no miente: la regla de hora funciona con la app viva.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'trigger.dart';

class TimeTickScheduler {
  TimeTickScheduler({required this.onMinute});

  /// Se invoca UNA vez por minuto (no por cada pulsación del timer).
  final FutureOr<void> Function(TickEvent event) onMinute;

  Timer? _timer;
  bool _running = false;

  /// Marca hhmm del último minuto emitido — dedupe de ticks dentro del
  /// mismo minuto (el timer pulsa cada 30s, el tick sale cada 60s).
  int _lastMinuteKey = -1;

  void start() {
    if (_timer != null) return;
    debugPrint('[rules] ticker arrancado (pulso 30s)');
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_running) return;
      final now = DateTime.now();
      final key = now.millisecondsSinceEpoch ~/ 60000;
      if (key == _lastMinuteKey) return;
      _lastMinuteKey = key;
      _running = true;
      try {
        await onMinute(TickEvent(now));
      } catch (error) {
        debugPrint('[rules] tick failed: $error');
      } finally {
        _running = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
