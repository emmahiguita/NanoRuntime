/// Verificación pura de una transición de navegación observada.
library;

import '../perception/current_situation.dart';
import 'navigation_decision.dart';
import 'navigation_goal.dart';
import 'navigation_history.dart';

enum NavigationTransitionStatus {
  initialObservation,
  goalReached,
  changed,
  unexpectedChange,
  unchanged,
}

final class NavigationTransition {
  const NavigationTransition(this.status, this.reason);

  final NavigationTransitionStatus status;
  final String reason;

  bool get isUnchanged => status == NavigationTransitionStatus.unchanged;
}

/// Compara la situación posterior con el último intento externo registrado.
///
/// No ejecuta, no decide la próxima acción y no convierte un cambio genérico
/// de pantalla en cumplimiento del objetivo.
final class NavigationTransitionVerifier {
  const NavigationTransitionVerifier();

  NavigationTransition verify({
    required NavigationHistory history,
    required CurrentSituation current,
    required NavigationGoal goal,
    required NavigationDecision decision,
  }) {
    final previous = history.lastEntry;
    final sameGoal =
        previous != null &&
        previous.goalSignature == navigationGoalSignature(goal);

    if (decision.diff.matchesTarget) {
      return NavigationTransition(
        NavigationTransitionStatus.goalReached,
        sameGoal
            ? 'transición verificada: el estado posterior satisface el objetivo'
            : 'objetivo verificado en la observación actual',
      );
    }
    if (!sameGoal) {
      return const NavigationTransition(
        NavigationTransitionStatus.initialObservation,
        'observación inicial; no existe una transición previa que verificar',
      );
    }

    final currentSignature = current.screenSignature;
    if (currentSignature == previous.situationSignature) {
      return NavigationTransition(
        NavigationTransitionStatus.unchanged,
        'transición no verificada: ${previous.action.kind.name} no produjo '
        'un cambio estructural observable',
      );
    }

    if (previous.action.kind == NavigationActionKind.launchPackage &&
        current.packageName != previous.action.packageName) {
      return NavigationTransition(
        NavigationTransitionStatus.unexpectedChange,
        'transición inesperada: el paquete observado es '
        '"${current.packageName}" y se esperaba '
        '"${previous.action.packageName}"',
      );
    }

    return NavigationTransition(
      NavigationTransitionStatus.changed,
      'transición observada después de ${previous.action.kind.name}; '
      'el objetivo aún no está demostrado',
    );
  }
}
