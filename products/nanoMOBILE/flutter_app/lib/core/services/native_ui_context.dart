import 'dart:async';

/// Transporta una precondición de ventana durante una única acción asíncrona.
/// Zone aísla ejecuciones concurrentes; no guarda estado global ni conversaciones.
abstract final class NativeUiContext {
  static final _key = Object();
  static Map<Object?, Object?>? get current =>
      Zone.current[_key] as Map<Object?, Object?>?;

  /// El contrato viaja hasta el canal de clic. Salir de la llamada, incluso por
  /// error, libera el alcance; otra acción no hereda esta identidad de chat.
  static Future<T> run<T>(Map contract, Future<T> Function() action) =>
      runZoned(
        action,
        zoneValues: {_key: Map<Object?, Object?>.unmodifiable(contract)},
      );
}
