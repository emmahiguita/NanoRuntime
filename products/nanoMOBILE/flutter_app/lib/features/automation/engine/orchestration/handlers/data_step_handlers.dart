/// Data step handlers — pasos de datos/URL/archivo (no interactúan con UI).
/// Cada clase = un paso = una responsabilidad.
library;

import '../../notifications/observed_data_extractor.dart';
import '../task_plan.dart';
import '../task_step_handler.dart';

class ReadNotificationHandler implements TaskStepHandler {
  const ReadNotificationHandler();

  @override
  String get semanticAction => 'readNotification';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final raw = await ctx.env.listNotifications();
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
}

class ExtractUrlHandler implements TaskStepHandler {
  const ExtractUrlHandler();

  @override
  String get semanticAction => 'extractUrl';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final binding = ctx.step.inputBindings['text'];
    final source = binding == null ? null : ctx.values[binding.source];
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
}

class WriteFileHandler implements TaskStepHandler {
  const WriteFileHandler();

  @override
  String get semanticAction => 'writeFile';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final binding = ctx.step.inputBindings['content'];
    final value = binding == null ? null : ctx.values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para escribir',
      );
    }
    const path = '/root/nano_observed_link.txt';
    final ok = await ctx.env.writeFile(path, value.url);
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
}

class OpenUrlHandler implements TaskStepHandler {
  const OpenUrlHandler();

  @override
  String get semanticAction => 'openUrl';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final binding = ctx.step.inputBindings['url'];
    final value = binding == null ? null : ctx.values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para abrir',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await ctx.env.openUrl(value.url);
    return ok
        ? const TaskStepResult(status: TaskStepStatus.completed, reason: 'URL abierta')
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'openUrl devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }
}
