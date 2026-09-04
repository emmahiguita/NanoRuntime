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
  final void Function(TickEvent event) onMinute;

  Timer? _timer;

  /// Marca hhmm del último minuto emitido — dedupe de ticks dentro del
  /// mismo minuto (el timer pulsa cada 30s, el tick sale cada 60s).
  int _lastMinuteKey = -1;

  void start() {
    if (_timer != null) return;
    debugPrint('[rules] ticker arrancado (pulso 30s)');
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      final key = (now.hour * 100) + now.minute;
      if (key == _lastMinuteKey) return;
      _lastMinuteKey = key;
      onMinute(TickEvent(now));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
