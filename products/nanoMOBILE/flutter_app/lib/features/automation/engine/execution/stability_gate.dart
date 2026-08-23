/// StabilityGate (Fase C4) — elimina delays ARBITRARIOS del agente.
///
/// Regla del plan maestro: NO `tap → Future.delayed(500)`. En su lugar:
/// tras una acción, esperar a que el árbol semántico se ASIENTE (N lecturas
/// consecutivas equivalentes) o vencer un plazo bounded. Si el árbol sigue
/// moviéndose (rebind ColorOS, animaciones, ventana en transición) el contador
/// de estabilidad se reinicia — nunca se declara "estable" un árbol en
/// movimiento.
///
/// Prioridad: la POSTCONDICIÓN esperada se evalúa en el [ActionVerifier]
/// (corta en cuanto se cumple); este gate solo decide "¿el mundo dejó de
/// moverse?" — es ortogonal y bounded.
library;

import '../perception/nano_snapshot.dart';

class StabilityResult {
  /// True si el árbol se asentó (N lecturas consecutivas equivalentes).
  final bool settled;

  /// Motivo legible (estable / inestable por plazo / canal off).
  final String reason;

  const StabilityResult(this.settled, this.reason);
}

/// Espera el asentamiento del árbol semántico. Puro: la fuente de snapshots
/// se inyecta ([snapshotFn]) — testeable con fakes.
class StabilityGate {
  StabilityGate({
    required Future<NanoSnapshot?> Function() snapshotFn,
    this.requiredStableReadings = 2,
    this.maxWait = const Duration(milliseconds: 900),
    this.pollInterval = const Duration(milliseconds: 150),
  }) : _snapshotFn = snapshotFn;

  final Future<NanoSnapshot?> Function() _snapshotFn;

  /// Lecturas consecutivas equivalentes para declarar estable.
  final int requiredStableReadings;

  /// Plazo máximo de espera (bounded, nunca infinito).
  final Duration maxWait;

  /// Intervalo entre lecturas.
  final Duration pollInterval;

  /// Sondea hasta asentarse o vencer [maxWait]. No lanza: todo resultado es
  /// tipado.
  Future<StabilityResult> waitSettled() async {
    final deadline = DateTime.now().add(maxWait);
    NanoSnapshot? prev;
    var stableReadings = 0;

    while (true) {
      final snap = await _snapshotFn();
      if (snap == null) {
        return const StabilityResult(
          false,
          'Canal de accesibilidad sin respuesta: no se puede medir '
          'estabilidad.',
        );
      }

      if (prev != null && equivalent(prev, snap)) {
        stableReadings++;
        if (stableReadings >= requiredStableReadings) {
          return StabilityResult(
            true,
            'Árbol estable tras $stableReadings lecturas consecutivas '
            'equivalentes.',
          );
        }
      } else {
        // El árbol se movió: el mundo sigue transicionando, reset del conteo.
        stableReadings = 0;
      }
      prev = snap;

      if (DateTime.now().isAfter(deadline)) {
        return StabilityResult(
          false,
          'El árbol no se asentó en ${maxWait.inMilliseconds}ms '
          '(movimiento continuo o lectura de conteo insuficiente).',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  /// Dos snapshots son equivalentes si package, conteo de nodos, textos y
  /// bounds coinciden (tolerancia: coordenadas exactas — un pixel de
  /// diferencia ya es movimiento).
  static bool equivalent(NanoSnapshot a, NanoSnapshot b) {
    if (a.package != b.package) return false;
    if (a.nodes.length != b.nodes.length) return false;
    for (var i = 0; i < a.nodes.length; i++) {
      final na = a.nodes[i];
      final nb = b.nodes[i];
      if (na.text != nb.text ||
          na.visible != nb.visible ||
          na.checked != nb.checked ||
          na.bounds.left != nb.bounds.left ||
          na.bounds.top != nb.bounds.top ||
          na.bounds.right != nb.bounds.right ||
          na.bounds.bottom != nb.bounds.bottom) {
        return false;
      }
    }
    return true;
  }
}
