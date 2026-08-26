/// A15.0 — TaskOrchestrator: ejecuta un TaskPlan paso a paso, transportando
/// TaskValues TIPADOS entre dominios.
///
/// NO es un segundo AutomationCoordinator ni un workflow engine libre. Cada paso
/// es semántico; la ejecución efectiva se delega a fuentes inyectadas (que a su
/// vez pasan por el pipeline Candidate-First + governance + verificación).
library;

import '../notifications/observed_data_extractor.dart';
import 'task_plan.dart';

class TaskOrchestrator {
  TaskOrchestrator({
    required Future<List<dynamic>> Function() listNotifications,
    required Future<bool> Function(String url) openUrl,
    required Future<bool> Function(String path, String content) writeFile,
    Future<bool> Function(String appName)? launchApp,
    Future<bool> Function(String selector)? tap,
    Future<bool> Function(String selector, String text)? writeText,
    this.maxAttemptsPerStep = 2,
    this.maxReplansPerTask = 2,
  }) : _listNotifications = listNotifications,
       _openUrl = openUrl,
       _writeFile = writeFile,
       _launchApp = launchApp,
       _tap = tap,
       _writeText = writeText;

  final Future<List<dynamic>> Function() _listNotifications;
  final Future<bool> Function(String url) _openUrl;
  final Future<bool> Function(String path, String content) _writeFile;

  /// A15.4 — fuentes UI (delegan al dispatcher/ScreenGraph).
  final Future<bool> Function(String appName)? _launchApp;
  final Future<bool> Function(String selector)? _tap;
  final Future<bool> Function(String selector, String text)? _writeText;

  /// A15.1 — presupuesto de recuperación acotado.
  final int maxAttemptsPerStep;
  final int maxReplansPerTask;

  /// Ejecuta el plan en orden topológico con recuperación ACOTADA (A15.1).
  /// Un paso no-completado detiene los dependientes. Los pasos fallidos
  /// recuperables se reintentan hasta el presupuesto; un reintento con el MISMO
  /// motivo (sin progreso) se detiene para evitar loops.
  Future<List<TaskStepResult>> run(TaskPlan plan) async {
    final invalid = plan.validate();
    if (invalid != null) {
      return [TaskStepResult(status: TaskStepStatus.failed, reason: invalid)];
    }

    final values = <TaskValueId, TaskValue>{};
    final results = <TaskStepResult>[];
    var replans = 0;
    final goalCtx = _parseGoal(plan.goal);

    for (final step in plan.ordered) {
      var result = await _runStep(step, values, goalCtx);
      var attempts = 1;

      while (!result.isCompleted &&
          result.isRecoverable &&
          attempts < maxAttemptsPerStep &&
          replans < maxReplansPerTask) {
        replans++;
        attempts++;
        final next = await _runStep(step, values, goalCtx);
        // Detección de loop: mismo motivo sin progreso → detener.
        if (next.reason == result.reason && !next.isCompleted) {
          result = next;
          break;
        }
        result = next;
      }

      results.add(result);
      if (!result.isCompleted) break;
      if (step.produces != null && result.output != null) {
        values[step.produces!] = result.output!;
      }
    }
    return results;
  }

  Future<TaskStepResult> _runStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values,
    _GoalContext goal,
  ) async {
    switch (step.semanticAction) {
      case 'readNotification':
        return _readNotification();
      case 'extractUrl':
        return _extractUrl(step, values);
      case 'writeFile':
        return _writeFileStep(step, values);
      case 'openUrl':
        return _openUrlStep(step, values);
      case 'openApp':
        return _openApp(goal);
      case 'openConversation':
        return _openConversation(goal);
      case 'writeMessage':
        return _writeMessage(goal);
      case 'sendMessage':
        return _sendMessage();
      default:
        return const TaskStepResult(
          status: TaskStepStatus.needsMoreEvidence,
          reason: 'semántica desconocida',
        );
    }
  }

  Future<TaskStepResult> _readNotification() async {
    final raw = await _listNotifications();
    final maps = raw.whereType<Map>().toList();
    if (maps.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin notificaciones activas',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final first = maps.first;
    final text = '${first['messageText'] ?? ''}'.isNotEmpty
        ? '${first['messageText']}'
        : '${first['text'] ?? ''}';
    return TaskStepResult(
      status: TaskStepStatus.completed,
      reason: 'notificación más reciente leída',
      output: TextValue(text),
    );
  }

  TaskStepResult _extractUrl(
    TaskStep step,
    Map<TaskValueId, TaskValue> values,
  ) {
    final binding = step.inputBindings['text'];
    final source = binding == null ? null : values[binding.source];
    if (source is! TextValue || source.text.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin texto fuente para extraer URL',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final data = const ObservedDataExtractor().extract(source.text);
    final url = data.primary;
    if (url == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'no se encontró URL en el texto observado',
        failureKind: TaskFailureKind.terminal,
      );
    }
    return TaskStepResult(
      status: TaskStepStatus.completed,
      reason: 'URL extraída',
      output: UrlValue(url),
    );
  }

  Future<TaskStepResult> _writeFileStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values,
  ) async {
    final binding = step.inputBindings['content'];
    final value = binding == null ? null : values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para escribir',
      );
    }
    const path = '/root/nano_observed_link.txt';
    final ok = await _writeFile(path, value.url);
    if (!ok) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'writeFile devolvió false',
        failureKind: TaskFailureKind.recoverable,
      );
    }
    return TaskStepResult(
      status: TaskStepStatus.completed,
      reason: 'URL escrita a archivo',
      output: const FilePathValue(path),
    );
  }

  Future<TaskStepResult> _openUrlStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values,
  ) async {
    final binding = step.inputBindings['url'];
    final value = binding == null ? null : values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para abrir',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await _openUrl(value.url);
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'URL abierta',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'openUrl devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }

  // ── A15.4 — pasos UI (delegan al dispatcher/ScreenGraph) ──────────────────

  Future<TaskStepResult> _openApp(_GoalContext goal) async {
    if (goal.appName.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin app en el objetivo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final launch = _launchApp;
    if (launch == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de launch',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await launch(goal.appName);
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'app abierta',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'launch devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }

  Future<TaskStepResult> _openConversation(_GoalContext goal) async {
    if (goal.target.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin conversación objetivo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final tap = _tap;
    if (tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de tap',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await tap('text=${goal.target}');
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'conversación abierta',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'tap de conversación devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }

  Future<TaskStepResult> _writeMessage(_GoalContext goal) async {
    if (goal.draft.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin borrador de mensaje',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final write = _writeText;
    if (write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de write',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await write('', goal.draft);
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'mensaje escrito',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'write devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }

  Future<TaskStepResult> _sendMessage() async {
    final tap = _tap;
    if (tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de tap',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await tap('desc=Enviar');
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'mensaje enviado (despacho aceptado)',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'tap de enviar devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }

  _GoalContext _parseGoal(String goal) {
    final g = goal.toLowerCase();
    final appMatch = RegExp(r'abre\s+(\w+)').firstMatch(g);
    final targetMatch = RegExp(
      r'(?:escríbele a|escribele a|escribe a|escríbale a|mensaje a|envía un mensaje a)\s+([^:]+)',
    ).firstMatch(g);
    final draftMatch = RegExp(r':\s*(.+)$').firstMatch(goal);
    return _GoalContext(
      appName: appMatch?.group(1) ?? '',
      target: (targetMatch?.group(1) ?? '').trim(),
      draft: (draftMatch?.group(1) ?? '').trim(),
    );
  }
}

class _GoalContext {
  final String appName;
  final String target;
  final String draft;
  const _GoalContext({this.appName = '', this.target = '', this.draft = ''});
}
