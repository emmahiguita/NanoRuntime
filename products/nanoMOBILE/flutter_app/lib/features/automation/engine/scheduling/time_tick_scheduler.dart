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
import 'package:shared_preferences/shared_preferences.dart';

import 'trigger.dart';

class TimeTickScheduler {
  static const _prefKey = 'automation.last_tick_minute';

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
    _restoreLastKey();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_running) return;
      final now = DateTime.now();
      final key = now.millisecondsSinceEpoch ~/ 60000;
      if (key <= _lastMinuteKey) return;
      _lastMinuteKey = key;
      _persistLastKey(key);
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

  Future<void> _restoreLastKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_prefKey);
      if (saved != null && saved > _lastMinuteKey) {
        _lastMinuteKey = saved;
      }
    } catch (_) {}
  }

  Future<void> _persistLastKey(int key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, key);
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
