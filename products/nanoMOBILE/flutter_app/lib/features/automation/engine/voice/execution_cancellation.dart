/// A16 — cancelación cooperativa propagada (sección 13 del documento).
///
/// Un token que viaja de la sesión de voz → AutomationCoordinator →
/// TaskOrchestrator → tool. "para"/"cancela" lo dispara; cada paso/tool
/// cooperativo chequea [throwIfCancelled] y aborta SIN esperar al LLM.
///
/// Las acciones IRREVERSIBLES ya completadas NO se deshacen: la cancelación
/// detiene el trabajo pendiente, no revierte efectos confirmados.
library;

/// Excepción lanzada cuando una ejecución cooperativa se cancela.
class ExecutionCancelled implements Exception {
  const ExecutionCancelled();
}

/// Token de cancelación cooperativo. Mutable y reutilizable entre turnos.
class ExecutionCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void reset() => _cancelled = false;

  /// Lanza [ExecutionCancelled] si se solicitó cancelación.
  void throwIfCancelled() {
    if (_cancelled) throw const ExecutionCancelled();
  }
}
