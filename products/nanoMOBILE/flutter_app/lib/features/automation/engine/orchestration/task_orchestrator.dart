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
    this.maxAttemptsPerStep = 2,
    this.maxReplansPerTask = 2,
  }) : _listNotifications = listNotifications,
       _openUrl = openUrl,
       _writeFile = writeFile;

  final Future<List<dynamic>> Function() _listNotifications;
  final Future<bool> Function(String url) _openUrl;
  final Future<bool> Function(String path, String content) _writeFile;

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

    for (final step in plan.ordered) {
      var result = await _runStep(step, values);
      var attempts = 1;

      while (!result.isCompleted &&
          result.isRecoverable &&
          attempts < maxAttemptsPerStep &&
          replans < maxReplansPerTask) {
        replans++;
        attempts++;
        final next = await _runStep(step, values);
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
}
