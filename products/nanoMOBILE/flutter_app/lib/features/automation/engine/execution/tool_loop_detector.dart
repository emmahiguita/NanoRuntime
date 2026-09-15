/// Detector de bucles del plan (C5). Heurística bounded, nunca infinito:
/// - patrón alternante A→B→A→B (los últimos 4 pasos son dos pares iguales);
/// - la misma acción 3+ veces en un plan de 5+ pasos.
class ToolLoopDetector {
  final List<String> _history = [];

  void reset() => _history.clear();

  bool isLoop(
    String fingerprint, {
    int repeatThreshold = 3,
    int minimumHistory = 5,
    bool detectAlternating = true,
  }) {
    _history.add(fingerprint);
    final n = _history.length;
    if (detectAlternating &&
        n >= 4 &&
        _history[n - 4] == _history[n - 2] &&
        _history[n - 3] == _history[n - 1]) {
      return true; // A→B→A→B
    }
    final count = _history.where((h) => h == fingerprint).length;
    if (count >= repeatThreshold && _history.length >= minimumHistory) {
      return true;
    }
    return false;
  }
}
