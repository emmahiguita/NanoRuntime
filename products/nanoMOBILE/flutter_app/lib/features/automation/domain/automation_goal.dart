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

class AutomationGoal {
  /// Texto libre del objetivo (p. ej. "abre Bluetooth").
  final String text;

  /// Expectativa de objetivo opcional (C3) para la comprobación final.
  final GoalExpectation? expectation;

  const AutomationGoal({required this.text, this.expectation});
}

/// Opciones de una ejecución concreta.
class AutomationOptions {
  /// Identificador asignado por el llamador para cancelación cooperativa.
  /// null → el coordinator genera uno.
  final String? executionId;

  /// True si el usuario ya confirmó las acciones sensibles del plan
  /// (externalWrite). Permite reanudar un plan pausado.
  final bool confirmed;

  /// Consentimiento vinculado a un único paso/acción del plan.
  final ActionConfirmation? confirmation;

  const AutomationOptions({
    this.executionId,
    this.confirmed = false,
    this.confirmation,
  });
}
