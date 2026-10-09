import 'dart:async';

// QUÉ: comparte el plazo de una herramienta con su cola y decoder nativo.
// CÓMO: una zona conserva un reloj monotónico y canceladores por request.
// POR QUÉ: Future.timeout solo deja de esperar; no detiene trabajo subyacente.
final class ExecutionBudget {
  ExecutionBudget(this.limit);
  static final Object _zoneKey = Object();
  static ExecutionBudget? get current =>
      Zone.current[_zoneKey] as ExecutionBudget?;
  final Duration limit;
  final Stopwatch _clock = Stopwatch()..start();
  final Set<void Function()> _cancellers = {};
  bool _cancelled = false;

  Duration get remaining {
    check();
    return limit - _clock.elapsed;
  }

  void check() {
    if (_cancelled || _clock.elapsed >= limit) {
      cancel();
      throw TimeoutException('Plazo de ejecución agotado', limit);
    }
  }

  Future<T> run<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: this});

  // Devuelve una baja idempotente; nunca cancela requests ajenos a esta zona.
  void Function() register(void Function() cancelRequest) {
    check();
    _cancellers.add(cancelRequest);
    return () => _cancellers.remove(cancelRequest);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in List<void Function()>.of(_cancellers)) {
      callback();
    }
    _cancellers.clear();
  }
}
