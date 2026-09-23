/// AUTOMATION-DASHBOARD-RUNNER — Orquestador de ejecución de tareas.
///
/// QUÉ HACE:
/// Ejecuta la meta ingresada por el usuario en [AutomationEngine] o diagnóstico,
/// gestiona cancelaciones y traduce resultados a lenguaje hablado (TTS).
///
/// CÓMO FUNCIONA:
/// Coordina la llamada async, notifica confirmaciones pendientes y actualiza el mundo.
///
/// POR QUÉ:
/// Desacopla la lógica pesada del ciclo de vida del árbol de widgets.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/nano_runtime_api.dart';
import '../../application/automation_diagnostics.dart';
import '../../application/automation_engine.dart';
import '../../application/automation_feedback_presenter.dart';
import '../../domain/automation_goal.dart';
import '../../domain/automation_result.dart';
import '../../engine/governance/action_confirmation.dart';

class AutomationDashboardRunner {
  static String spokenResult(AutomationResult result) {
    final prefix = switch (result.status) {
      AutomationResultStatus.completed => 'Tarea completada.',
      AutomationResultStatus.completedUnverified =>
        'La tarea terminó, pero no pude verificar el objetivo final.',
      AutomationResultStatus.paused => 'Necesito tu confirmación.',
      AutomationResultStatus.denied => 'La acción fue denegada.',
      AutomationResultStatus.noPlan => 'No encontré un plan verificable.',
      AutomationResultStatus.failed => 'No pude completar la tarea.',
      AutomationResultStatus.outcomeUnknown =>
        'No pude comprobar el resultado de la acción.',
      AutomationResultStatus.cancelled => 'La tarea fue cancelada.',
    };
    final reason = automationSpokenReason(result.reason);
    return reason.isEmpty ? prefix : '$prefix $reason';
  }

  static Future<AutomationResult?> execute({
    required String text,
    required AutomationEngine engine,
    required AutomationDiagnostics diagnostics,
    ActionConfirmation? confirmation,
    String? executionId,
  }) async {
    final goal = text.trim();
    if (goal.isEmpty) return null;

    if (confirmation != null) {
      unawaited(NanoRuntimeApi.instance.dismissAutomationConfirmation());
    }

    try {
      if (isDiagCommand(goal)) {
        return await diagnostics.run(goal);
      }
      return await engine.runGoal(
        AutomationGoal(text: goal),
        options: AutomationOptions(
          executionId: executionId,
          confirmation: confirmation,
          confirmed: confirmation != null,
        ),
      );
    } catch (e, stack) {
      debugPrint('[automation_runner] Error al ejecutar tarea: $e\n$stack');
      return AutomationResult(
        executionId: executionId ?? 'err',
        status: AutomationResultStatus.failed,
        reason: 'Error al ejecutar la tarea: $e',
      );
    }
  }
}
