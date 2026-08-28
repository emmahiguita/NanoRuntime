/// App step handler — abrir app/destino, con derivación de app de mensajería
/// desde la notificación activa (T2.8).
library;

import '../../notifications/notification_object.dart';
import '../task_plan.dart';
import '../task_step_handler.dart';

class OpenAppHandler implements TaskStepHandler {
  const OpenAppHandler();

  @override
  String get semanticAction => 'openApp';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final app = await _resolveMessagingApp(ctx);
    if (app == null || app.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin app en el objetivo ni en notificaciones',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final launch = ctx.env.launchApp;
    if (launch == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de launch',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await launch(app);
    return ok
        ? const TaskStepResult(status: TaskStepStatus.completed, reason: 'app abierta')
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'launch devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }

  /// App explícita del objetivo o, si falta, el packageName de la notificación
  /// activa cuyo sender/conversación matchea el target (evidencia real).
  Future<String?> _resolveMessagingApp(StepContext ctx) async {
    final goal = ctx.goal;
    if (goal.appName.isNotEmpty) return goal.appName;
    if (goal.target.isEmpty) return null;

    final raw = await ctx.env.listNotifications();
    for (final m in raw.whereType<Map>()) {
      final n = NotificationObject.fromMap(m.cast<dynamic, dynamic>());
      if (n.packageName.isEmpty) continue;
      if (n.matchesRecipient(goal.target)) return n.packageName;
    }
    return null;
  }
}
