/// WA-CONV-03 — TurnSupersedeGuard: versión monotónica por conversación.
///
/// Cada mensaje REAL entrante de una conversación incrementa su versión. El
/// dispatcher captura la versión al empezar un reply dinámico y, tras el
/// borrador (y justo antes de ejecutar el envío), si la versión cambió, el
/// turno quedó SUPERADO: llegó un mensaje nuevo mientras Nano redactaba y
/// responder al estado viejo sería incorrecto ("no, mejor el azul" mientras
/// Nano redactaba "sí, el negro..."). Resultado honesto: failed con razón
/// 'turno superado' — jamás se envía el draft viejo.
///
/// Puro: un contador por ConversationKey id; la decisión es comparación de
/// igualdad (monotónica, sin relojes). Los incrementos vienen de TODAS las
/// entradas reales: el push del BurstTurnGate (incluye mensajes que llegan
/// durante el turno) y el proceed del RulePipeline (rutas sin gate).
library;

/// Instancia única por engine: la comparten el BurstTurnGate (bump en cada
/// inbound), el RulePipeline y el RuleDispatcher (captura/verificación).
final class TurnSupersedeGuard {
  final Map<String, int> _versions = {};

  void invalidateAll() => _versions.clear();

  /// Versión actual de la conversación (0 = nunca se vio un mensaje).
  int versionOf(String conversationId) {
    if (conversationId.isEmpty) return 0;
    return _versions[conversationId] ?? 0;
  }

  /// Snapshot de la versión actual por conversación.
  int snapshot(String conversationId) => versionOf(conversationId);

  /// Registra un mensaje REAL entrante por conversación. Devuelve la versión nueva.
  int bump(String conversationId) {
    if (conversationId.isEmpty) return 0;
    final current = _versions[conversationId] ?? 0;
    final next = current + 1;
    _versions[conversationId] = next;
    if (_versions.length > 800) _versions.remove(_versions.keys.first);
    return next;
  }

  /// Comprueba si la versión esperada sigue siendo la actual para la conversación.
  bool isCurrent(String conversationId, int expectedVersion) {
    return versionOf(conversationId) == expectedVersion;
  }
}
