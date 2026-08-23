/// ActionLedger — memoria acotada de ejecuciones reales (ledger).
///
/// Append-only en memoria, bounded (LRU simple por antigüedad). Es la fuente
/// de verdad de "qué hizo realmente el motor", para auditoría, depuración del
/// coordinator y el benchmark físico (C14). La persistencia (C13 NanoRecorder)
/// viene después de estabilizar el benchmark; aquí el contrato es el ledger.
library;

import 'automation_trace.dart';

class ActionLedger {
  final int maxEntries;
  final List<AutomationTrace> _entries = <AutomationTrace>[];

  ActionLedger({this.maxEntries = 200});

  /// Trazas registradas (recientes primero).
  List<AutomationTrace> get entries => List.unmodifiable(_entries.reversed);

  /// Trazas de un objetivo concreto (sin normalizar: coincidencia exacta).
  List<AutomationTrace> forGoal(String goal) =>
      _entries.where((t) => t.goal == goal).toList(growable: false);

  int get size => _entries.length;

  void record(AutomationTrace trace) {
    _entries.add(trace);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0); // expulsar la más antigua (bounded).
    }
  }

  void clear() => _entries.clear();
}
