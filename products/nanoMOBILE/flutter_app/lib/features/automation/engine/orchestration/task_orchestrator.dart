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
  }) : _listNotifications = listNotifications,
       _openUrl = openUrl,
       _writeFile = writeFile;

  final Future<List<dynamic>> Function() _listNotifications;
  final Future<bool> Function(String url) _openUrl;
  final Future<bool> Function(String path, String content) _writeFile;

  /// Ejecuta el plan en orden topológico. Un paso no-completado detiene los
  /// dependientes (no se ejecutan pasos huérfanos).
  Future<List<TaskStepResult>> run(TaskPlan plan) async {
    final invalid = plan.validate();
    if (invalid != null) {
      return [TaskStepResult(status: TaskStepStatus.failed, reason: invalid)];
    }

    final values = <TaskValueId, TaskValue>{};
    final results = <TaskStepResult>[];

    for (final step in plan.ordered) {
      final r = await _runStep(step, values);
      results.add(r);
      if (!r.isCompleted) break;
      if (step.produces != null && r.output != null) {
        values[step.produces!] = r.output!;
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
      );
    }
    final data = const ObservedDataExtractor().extract(source.text);
    final url = data.primary;
    if (url == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'no se encontró URL en el texto observado',
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
          );
  }
}
