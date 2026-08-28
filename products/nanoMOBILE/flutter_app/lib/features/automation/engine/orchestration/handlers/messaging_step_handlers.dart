/// Messaging step handlers — abrir conversación, escribir mensaje, enviar con
/// verificación por observación (T2.7).
library;

import '../task_plan.dart';
import '../task_step_handler.dart';

class OpenConversationHandler implements TaskStepHandler {
  const OpenConversationHandler();

  @override
  String get semanticAction => 'openConversation';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final target = ctx.goal.target;
    if (target.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin conversación objetivo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final tap = ctx.env.tap;
    if (tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de tap',
        failureKind: TaskFailureKind.terminal,
      );
    }

    // Ruta directa: la conversación ya está visible como texto.
    if (await tap('text=$target')) {
      return const TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'conversación abierta',
      );
    }

    // Fallback de búsqueda: icono → campo → escribir → resultado.
    final resolveInput = ctx.env.resolveInputSurface;
    final resolveAction = ctx.env.resolveActionSurface;
    final write = ctx.env.writeText;
    if (resolveInput == null || resolveAction == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'conversación no visible y sin búsqueda disponible',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    final searchIcon = await resolveAction('search');
    if (searchIcon != null && searchIcon.isNotEmpty) {
      await tap(searchIcon);
    }

    final input = await resolveInput();
    if (input == null || input.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'sin campo de búsqueda para localizar la conversación',
        failureKind: TaskFailureKind.recoverable,
      );
    }
    if (!await write(input, target)) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'no se pudo escribir el target en la búsqueda',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    // editable=false excluye el propio campo de búsqueda (que contiene el target).
    if (await tap('text=$target;editable=false')) {
      return const TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'conversación abierta vía búsqueda',
      );
    }
    return const TaskStepResult(
      status: TaskStepStatus.failed,
      reason: 'resultado de búsqueda no encontrado',
      failureKind: TaskFailureKind.recoverable,
    );
  }
}

class WriteMessageHandler implements TaskStepHandler {
  const WriteMessageHandler();

  @override
  String get semanticAction => 'writeMessage';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final draft = ctx.goal.draft;
    if (draft.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin borrador de mensaje',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolve = ctx.env.resolveInputSurface;
    final write = ctx.env.writeText;
    if (resolve == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación de pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final selector = await resolve();
    if (selector == null || selector.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin superficie de entrada editable visible',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await write(selector, draft);
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'mensaje escrito en superficie editable',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'write devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }
}

class SendMessageHandler implements TaskStepHandler {
  const SendMessageHandler();

  @override
  String get semanticAction => 'sendMessage';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final resolve = ctx.env.resolveActionSurface;
    final tap = ctx.env.tap;
    if (resolve == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de tap/observación de pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final selector = await resolve('send');
    if (selector == null || selector.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin botón de envío identificable',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await tap(selector);
    if (!ok) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'tap de enviar devolvió false',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    // Verificación de envío por observación: el composer debe quedar vacío.
    final observe = ctx.env.observeInputText;
    if (observe == null) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'envío despachado; sin fuente de observación para verificar',
      );
    }
    final remaining = await observe();
    if (remaining == null) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'envío despachado; superficie de entrada no observable',
      );
    }
    final draft = ctx.goal.draft;
    if (draft.isNotEmpty && remaining.contains(draft)) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'composer aún contiene el borrador tras enviar',
        failureKind: TaskFailureKind.recoverable,
      );
    }
    return const TaskStepResult(
      status: TaskStepStatus.completed,
      reason: 'mensaje enviado y composer vaciado',
    );
  }
}
