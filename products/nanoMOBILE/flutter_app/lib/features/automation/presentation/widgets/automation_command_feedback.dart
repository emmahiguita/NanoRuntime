// QUÉ: estado honesto de respuestas textuales de herramientas.
// CÓMO: respeta marcadores de verificación y detecta comandos desconocidos.
// POR QUÉ: recibir texto no demuestra que una acción haya sido completada.
library;

import '../../domain/automation_result.dart';
import '../../engine/execution/plan_execution_coordinator.dart';

class AutomationCommandFeedback {
  const AutomationCommandFeedback._();
  static AutomationResultStatus statusFor(String feedback) {
    final text = feedback.trim();
    if (text.isEmpty || text.startsWith('Comando desconocido')) {
      return AutomationResultStatus.failed;
    }
    if (text.startsWith('[completed]')) return AutomationResultStatus.completed;
    if (text.startsWith('[timeoutOutcomeUnknown]') ||
        text.startsWith('[outcomeUnknown]')) {
      return AutomationResultStatus.outcomeUnknown;
    }
    if (text.startsWith('[completedUnverified]')) {
      return AutomationResultStatus.completedUnverified;
    }
    if (PlanExecutionCoordinator.isFailedFeedback(text)) {
      return AutomationResultStatus.failed;
    }
    // Texto informativo sin evidencia explícita no se presenta como éxito verificado.
    return AutomationResultStatus.completedUnverified;
  }
}
