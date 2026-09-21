import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/governance/action_confirmation.dart';

import '../../../core/models/chat_models.dart';
import '../domain/chat_turn_route_result.dart';
import '../domain/tool_approval_result.dart';

/// Coordinador del ciclo de vida de herramientas del LLM, detección de bucles
/// y gobernanza con confirmación humana previa a la ejecución.
///
/// **QUÉ HACE:**
/// Mantiene en memoria los planes de automatización o tareas pendientes de
/// confirmación de seguridad y procesa las aprobaciones o rechazos del usuario.
///
/// **CÓMO FUNCIONA:**
/// - Guarda el plan o goal pausado con su firma criptográfica de confirmación.
/// - Detecta ciclos infinitos de tools (`ToolLoopDetector`).
/// - Al aprobarse, reanuda la ejecución en `AutomationCoordinator` y emite el resultado.
///
/// **POR QUÉ:**
/// Garantiza el control humano (Human-In-The-Loop) antes de ejecutar acciones
/// sensibles en el dispositivo y previene que el agente caiga en bucles recursivos.
class ChatToolCoordinator {
  static const int maxToolRounds = 8;
  final ToolLoopDetector _roundLoopDetector = ToolLoopDetector();

  String _pendingUserText = '';
  List<String> _pendingTrace = const [];
  String _pendingCallText = '';

  List<ToolCall>? _pendingPlan;
  int? _pendingPlanIndex;
  ActionConfirmation? _pendingPlanConfirmation;

  String? _pendingTaskGoal;
  ActionConfirmation? _pendingTaskConfirmation;

  bool get hasPendingTool => _pendingPlan != null || _pendingTaskGoal != null;

  void reset() {
    _roundLoopDetector.reset();
    _pendingPlan = null;
    _pendingPlanIndex = null;
    _pendingPlanConfirmation = null;
    _pendingTaskGoal = null;
    _pendingTaskConfirmation = null;
    _pendingUserText = '';
    _pendingTrace = const [];
    _pendingCallText = '';
  }

  void pausePlan({
    required List<ToolCall> plan,
    required int? pauseIndex,
    required ActionConfirmation? confirmation,
    required String userText,
    required List<String> trace,
    required String callText,
  }) {
    _pendingPlan = plan;
    _pendingPlanIndex = pauseIndex;
    _pendingPlanConfirmation = confirmation;
    _pendingUserText = userText;
    _pendingTrace = trace;
    _pendingCallText = callText;
  }

  void pauseTask({
    required String taskGoal,
    required ActionConfirmation confirmation,
    required String userText,
    required List<String> trace,
    required String callText,
  }) {
    _pendingTaskGoal = taskGoal;
    _pendingTaskConfirmation = confirmation;
    _pendingUserText = userText;
    _pendingTrace = trace;
    _pendingCallText = callText;
  }

  /// Pausa una ruta previa detectada por `ChatTurnRouter`.
  void pauseFromRoute(ChatTurnRouteResult route, String userText) {
    if (route.pausedPlan != null) {
      pausePlan(
        plan: route.pausedPlan!,
        pauseIndex: route.pausedPlanIndex,
        confirmation: route.pausedPlanConfirmation,
        userText: userText,
        trace: const [],
        callText: '',
      );
    } else if (route.pausedTaskGoal != null && route.pausedTaskConfirmation != null) {
      pauseTask(
        taskGoal: route.pausedTaskGoal!,
        confirmation: route.pausedTaskConfirmation!,
        userText: userText,
        trace: const [],
        callText: '',
      );
    }
  }

  bool isStalledToolRound({
    required List<ToolCall> calls,
    required String before,
    required String after,
    required String feedback,
  }) {
    final sig = calls.map((c) => c.confirmationSignature).join('\u001f');
    return _roundLoopDetector.isLoop('$sig\u001d$before\u001d$after\u001d$feedback', repeatThreshold: 2, minimumHistory: 2, detectAlternating: false);
  }

  /// El usuario aprobó la herramienta pendiente.
  Future<ToolApprovalResult?> approvePending({required AutomationCoordinator coordinator}) async {
    if (_pendingTaskGoal != null) return _approveTask(coordinator);
    if (_pendingPlan != null) return _approvePlan(coordinator);
    return null;
  }

  Future<ToolApprovalResult?> _approveTask(AutomationCoordinator coordinator) async {
    final taskGoal = _pendingTaskGoal!;
    final conf = _pendingTaskConfirmation;
    _pendingTaskGoal = null;
    _pendingTaskConfirmation = null;
    if (conf == null) return null;

    final resumed = await coordinator.tryCrossApp(taskGoal, confirmation: conf);
    if (resumed == null) return null;
    final r = resumed.result;
    if (r.isPaused && r.confirmation != null) {
      _pendingTaskGoal = taskGoal;
      _pendingTaskConfirmation = r.confirmation;
      return ToolApprovalResult(pendingTool: r.pauseTool, pendingToolDescription: automationUserFacingReason(r.reason));
    }
    final isErr = const {AutomationResultStatus.failed, AutomationResultStatus.outcomeUnknown, AutomationResultStatus.denied, AutomationResultStatus.cancelled}.contains(r.status);
    return ToolApprovalResult(
      completedMessage: ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: 'Ejecutado en el dispositivo (sin LLM):\n${automationUserFacingReason(r.reason)}',
        timestamp: DateTime.now(),
        source: MessageSource.device,
        status: isErr ? MessageStatus.error : MessageStatus.sent,
      ),
    );
  }

  Future<ToolApprovalResult?> _approvePlan(AutomationCoordinator coordinator) async {
    final plan = _pendingPlan!;
    final conf = _pendingPlanConfirmation;
    final userText = _pendingUserText;
    final trace = _pendingTrace;
    final callText = _pendingCallText;
    _pendingPlan = null;
    _pendingPlanIndex = null;
    _pendingPlanConfirmation = null;
    if (conf == null) return null;

    final r = await coordinator.execute(AutomationGoal(text: userText), plan: plan, options: AutomationOptions(confirmation: conf));
    if (r.isPaused && r.confirmation != null) {
      _pendingPlan = plan;
      _pendingPlanIndex = r.pauseIndex;
      _pendingPlanConfirmation = r.confirmation;
      return ToolApprovalResult(pendingTool: r.pauseTool, pendingToolDescription: automationUserFacingReason(r.reason));
    }
    return ToolApprovalResult(shouldResumeGeneration: true, resumeUserText: userText, resumeTrace: [...trace, callText, automationUserFacingReason(r.reason)]);
  }

  /// El usuario rechazó la herramienta pendiente.
  ({String userText, List<String> trace})? rejectPending(String? currentPendingTool) {
    if ((_pendingPlan == null && _pendingTaskGoal == null) || currentPendingTool == null) return null;
    final toolName = _pendingTaskGoal != null ? currentPendingTool : _pendingPlan![_pendingPlanIndex ?? 0].tool;
    final userText = _pendingUserText;
    final trace = _pendingTrace;
    final callText = _pendingCallText;
    reset();
    return (userText: userText, trace: [...trace, callText, '🚫 [policy] $toolName cancelada por el usuario (sin confirmación).']);
  }
}
