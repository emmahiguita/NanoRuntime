// browser_ai_synchronizer.dart — Sincronización y exclusión mutua para consultas web.
// QUÉ HACE: Garantiza que solo una consulta por proveedor web ocurra a la vez y espera login con backoff.
// CÓMO FUNCIONA: Usa una cadena de Completers para evitar deadlocks y un bucle de comprobación temporal.
// POR QUÉ: Desacopla la lógica de concurrencia y temporización del Gateway principal (<200 líneas).
library;

import 'dart:async';

class BrowserAiSynchronizer {
  final Map<String, Future<void>> _providerLocks = {};

  /// Ejecuta [action] con exclusión mutua para la clave dada (providerId).
  Future<T> synchronized<T>(String key, Future<T> Function() action) async {
    final previous = _providerLocks[key] ?? Future<void>.value();
    final completer = Completer<void>();
    _providerLocks[key] = completer.future;
    try {
      await previous;
      return await action();
    } finally {
      if (identical(_providerLocks[key], completer.future)) {
        _providerLocks.remove(key);
      }
      if (!completer.isCompleted) completer.complete();
    }
  }

  /// Espera acotada con backoff a que la función [check] devuelva true (sesión lista).
  static Future<bool> waitUntilLoggedIn(
    Future<bool> Function() check, {
    List<Duration> retryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1200),
      Duration(milliseconds: 1600),
    ],
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final deadline = DateTime.now().add(timeout);

    Future<bool> checkBeforeDeadline() async {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return false;
      return check().timeout(remaining, onTimeout: () => false);
    }

    if (await checkBeforeDeadline()) return true;

    for (final delay in retryDelays) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return false;
      await Future<void>.delayed(delay < remaining ? delay : remaining);
      if (await checkBeforeDeadline()) return true;
    }

    return false;
  }
}
