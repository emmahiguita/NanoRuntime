import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/governance/action_confirmation.dart';

import '../../../core/models/chat_models.dart';

/// Representa el resultado inmutable del pre-enrutamiento determinista de un turno.
///
/// **QUÉ HACE:**
/// Encapsula si un mensaje de usuario fue resuelto por comandos locales, cancelaciones
/// o tareas sin LLM, o si se pausó para confirmación del usuario, o si debe continuar al LLM.
///
/// **CÓMO FUNCIONA:**
/// Emplea constructores con nombre tipo factory (`notHandled`, `completed`, `pausePlan`, `pauseTask`)
/// para modelar los distintos estados posibles del enrutador de forma exhaustiva.
///
/// **POR QUÉ:**
/// Separar este modelo de dominio del algoritmo de enrutamiento permite que ambos archivos
/// se mantengan por debajo del límite estricto de 200 líneas (SRP & Clean Architecture).
class ChatTurnRouteResult {
  /// Indica si el turno fue absorbido por alguna regla local (no requiere pasar al motor LLM).
  final bool isHandled;

  /// Mensaje de respuesta final generado si el turno concluyó localmente.
  final ChatMessage? message;

  /// Indica si la acción requiere una confirmación explícita del usuario (política de gobernanza).
  final bool isPaused;

  /// Nombre de la herramienta pendiente de confirmación humana.
  final String? pauseTool;

  /// Descripción comprensible para mostrar en el diálogo de confirmación.
  final String? pauseDescription;

  /// Plan multi-paso pendiente de ejecución a partir del paso pausado.
  final List<ToolCall>? pausedPlan;

  /// Índice del paso del plan que causó la pausa por requerir confirmación.
  final int? pausedPlanIndex;

  /// Firma criptográfica de confirmación del paso pendiente.
  final ActionConfirmation? pausedPlanConfirmation;

  /// Objetivo de la tarea semántica pausada (Cross-App / TaskPlanner).
  final String? pausedTaskGoal;

  /// Confirmación asociada a la tarea semántica en pausa.
  final ActionConfirmation? pausedTaskConfirmation;

  /// Ruta de archivo Linux actualizado si el comando realizó una escritura verificada.
  final String? updatedLastLinuxFilePath;

  const ChatTurnRouteResult._({
    required this.isHandled,
    this.message,
    this.isPaused = false,
    this.pauseTool,
    this.pauseDescription,
    this.pausedPlan,
    this.pausedPlanIndex,
    this.pausedPlanConfirmation,
    this.pausedTaskGoal,
    this.pausedTaskConfirmation,
    this.updatedLastLinuxFilePath,
  });

  /// Constructor para turnos no interceptados que deben continuar al motor LLM.
  const ChatTurnRouteResult.notHandled() : this._(isHandled: false);

  /// Constructor para turnos completados deterministamente sin invocar el LLM.
  factory ChatTurnRouteResult.completed(
    ChatMessage message, {
    String? lastLinuxFilePath,
  }) => ChatTurnRouteResult._(
    isHandled: true,
    message: message,
    updatedLastLinuxFilePath: lastLinuxFilePath,
  );

  /// Constructor para pausar la ejecución de un plan multi-paso por requerir confirmación.
  factory ChatTurnRouteResult.pausePlan({
    required List<ToolCall> plan,
    required int? pauseIndex,
    required ActionConfirmation? confirmation,
    required String? pauseTool,
    required String? pauseDescription,
  }) => ChatTurnRouteResult._(
    isHandled: true,
    isPaused: true,
    pauseTool: pauseTool,
    pauseDescription: pauseDescription,
    pausedPlan: plan,
    pausedPlanIndex: pauseIndex,
    pausedPlanConfirmation: confirmation,
  );

  /// Constructor para pausar una tarea semántica cross-app por requerir confirmación.
  factory ChatTurnRouteResult.pauseTask({
    required String taskGoal,
    required ActionConfirmation confirmation,
    required String? pauseTool,
    required String? pauseDescription,
  }) => ChatTurnRouteResult._(
    isHandled: true,
    isPaused: true,
    pauseTool: pauseTool,
    pauseDescription: pauseDescription,
    pausedTaskGoal: taskGoal,
    pausedTaskConfirmation: confirmation,
  );
}
