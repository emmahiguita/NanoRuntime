/// Objetivo de automatización — el contrato del dominio del módulo.
///
/// Un [AutomationGoal] es declarativo: describe la INTENCIÓN. Cómo se
/// convierte en acciones verificadas lo decide el [AutomationCoordinator]
/// (único dueño del ciclo de ejecución).
///
/// Ningún source externo (chat, notificaciones, voz, eventos, scheduler)
/// debería acoplarse al motor; todos producen un [AutomationGoal] y el módulo
/// decide el camino (flujo verificado en cache o planner).
library;

import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation;
import 'package:nanoai/features/automation/engine/governance/action_confirmation.dart'
    show ActionConfirmation;
import 'package:nanoai/features/automation/engine/navigation/navigation_goal.dart'
    show NavigationGoal;
import 'package:nanoai/features/automation/engine/navigation/situation_diff.dart'
    show SituationDiff;
import 'package:nanoai/features/automation/engine/perception/current_situation.dart'
    show CurrentSituation;

class AutomationGoal {
  /// Texto libre del objetivo (p. ej. "abre Bluetooth").
  final String text;

  /// Expectativa de objetivo opcional (C3) para la comprobación final.
  final GoalExpectation? expectation;

  /// Destino semántico opcional para objetivos que requieren navegación.
  final NavigationGoal? navigationGoal;

  const AutomationGoal({
    required this.text,
    this.expectation,
    this.navigationGoal,
  });

  /// Explica la distancia entre el estado observado y el destino declarado.
  /// Sin destino de navegación no fabrica una diferencia.
  SituationDiff? navigationDiffFrom(CurrentSituation current) {
    final target = navigationGoal;
    return target == null ? null : SituationDiff.between(current, target);
  }
}

/// Opciones de una ejecución concreta.
class AutomationOptions {
  /// Identificador asignado por el llamador para cancelación cooperativa.
  /// null → el coordinator genera uno.
  final String? executionId;

  /// Compatibilidad legacy. No eleva privilegios ni sustituye a
  /// [confirmation]; una reanudación sensible exige el token exacto.
  final bool confirmed;

  /// Consentimiento vinculado a un único paso/acción del plan.
  final ActionConfirmation? confirmation;

  const AutomationOptions({
    this.executionId,
    this.confirmed = false,
    this.confirmation,
  });
}
