// Serializa el inbox JSON dentro de un isolate para evitar escrituras concurrentes.
// No sustituye una transacción SQLite ni garantiza entrega exactamente una vez.
class BusinessTurnSerialQueue {
  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    // Un fallo no deja bloqueados los turnos posteriores; el llamador lo recibe.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
