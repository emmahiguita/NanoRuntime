/// AUT-MEM-01 — VerifiedTransitionMemory: mapa operativo aprendido.
///
/// Registra SOLO transiciones verificadas por el ciclo real: PRE(acción)→POST
/// confirmado por la reobservación (NavigationTransitionVerifier). Nunca
/// registra una acción por haber sido despachada.
///
/// La memoria SOLO sugiere (hint de orden); la pantalla actual SIEMPRE
/// verifica antes de ejecutar y después de cada acción.
/// INVARIANTE: MEMORY MAY PROPOSE; CURRENT SCREEN MUST VERIFY.
library;

import '../navigation/navigation_decision.dart';
import '../perception/current_situation.dart';

/// Transición verificada entre superficies de una familia de paquetes.
final class VerifiedTransition {
  const VerifiedTransition({
    required this.packageName,
    required this.fromSurface,
    required this.action,
    required this.resultingSurface,
    required this.observations,
  });

  final String packageName;
  final CurrentSurfaceKind fromSurface;
  final NavigationActionKind action;
  final CurrentSurfaceKind resultingSurface;
  final int observations;

  /// Proporción de observaciones exitosas (todas lo fueron: solo se registra
  /// lo verificado). Para el ranking de sugerencias.
  double get confidence => observations.toDouble();
}

/// Memoria de transiciones verificadas (en memoria, por sesión).
///
/// La persistencia durable y la invalidación por appVersion son fases
/// posteriores (NAV-MAP-06).
final class VerifiedTransitionMemory {
  final Map<String, VerifiedTransition> _byKey = {};

  bool get isEmpty => _byKey.isEmpty;

  /// Registra (o refuerza) una transición verificada por la observación POST.
  void record({
    required String packageName,
    required CurrentSurfaceKind fromSurface,
    required NavigationActionKind action,
    required CurrentSurfaceKind resultingSurface,
  }) {
    final key = _key(packageName, fromSurface, action, resultingSurface);
    final existing = _byKey[key];
    _byKey[key] = VerifiedTransition(
      packageName: packageName,
      fromSurface: fromSurface,
      action: action,
      resultingSurface: resultingSurface,
      observations: (existing?.observations ?? 0) + 1,
    );
  }

  /// Sugiere acciones que, desde esta superficie y familia, llevaron a la
  /// superficie objetivo — ordenadas por observaciones (más confirmadas
  /// primero). Vacío si no hay conocimiento aplicable.
  List<NavigationActionKind> suggest({
    required String packageName,
    required CurrentSurfaceKind fromSurface,
    required CurrentSurfaceKind targetSurface,
  }) {
    final matches = [
      for (final entry in _byKey.values)
        if (entry.packageName == packageName &&
            entry.fromSurface == fromSurface &&
            entry.resultingSurface == targetSurface)
          entry,
    ]..sort((a, b) => b.observations.compareTo(a.observations));
    return List.unmodifiable(
      matches.map((entry) => entry.action).toSet().toList(growable: false),
    );
  }

  String _key(
    String packageName,
    CurrentSurfaceKind from,
    NavigationActionKind action,
    CurrentSurfaceKind result,
  ) => '$packageName|${from.name}|${action.name}|${result.name}';
}
