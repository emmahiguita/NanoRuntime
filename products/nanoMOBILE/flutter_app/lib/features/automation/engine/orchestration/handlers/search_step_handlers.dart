/// Search step handlers — escribir query, submit, y selección semántica de
/// resultado con verificación por observación (T2.9 + SearchResultVerification).
library;

import '../../perception/search_result_resolver.dart';
import '../task_plan.dart';
import '../task_step_handler.dart';

class WriteQueryHandler implements TaskStepHandler {
  const WriteQueryHandler();

  @override
  String get semanticAction => 'writeQuery';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final query = ctx.goal.query;
    if (query.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin query de búsqueda',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolveInput = ctx.env.resolveInputSurface;
    final write = ctx.env.writeText;
    if (resolveInput == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación',
        failureKind: TaskFailureKind.terminal,
      );
    }

    var input = await resolveInput();
    if (input == null || input.isEmpty) {
      final resolveAction = ctx.env.resolveActionSurface;
      final tap = ctx.env.tap;
      if (resolveAction == null || tap == null) {
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'sin campo de búsqueda ni fuente para abrirlo',
          failureKind: TaskFailureKind.recoverable,
        );
      }
      final icon = await resolveAction('search');
      if (icon == null || icon.isEmpty) {
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'sin superficie de búsqueda',
          failureKind: TaskFailureKind.recoverable,
        );
      }
      await tap(icon);
      input = await resolveInput();
      if (input == null || input.isEmpty) {
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'el icono de búsqueda no abrió un campo editable',
          failureKind: TaskFailureKind.recoverable,
        );
      }
    }

    final ok = await write(input, query);
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'query escrita en el campo de búsqueda',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'write devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }
}

class SubmitSearchHandler implements TaskStepHandler {
  const SubmitSearchHandler();

  @override
  String get semanticAction => 'submitSearch';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final resolveAction = ctx.env.resolveActionSurface;
    final tap = ctx.env.tap;
    if (resolveAction == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'query escrita; sin fuente para submit',
      );
    }
    final action = await resolveAction('search');
    if (action == null || action.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'query escrita; sin botón de submit (búsqueda en vivo)',
      );
    }

    final readText = ctx.env.readVisibleText;
    final detect = ctx.env.detectSearchResults;
    final before = readText != null ? await readText() : null;

    final ok = await tap(action);
    if (!ok) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'tap de submit devolvió false',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    // SearchResultVerification — "tecla aceptada" NO es búsqueda.
    final after = readText != null ? await readText() : null;
    final results = detect != null ? await detect() : null;
    final changed = before != null && after != null && before != after;
    final hasResults = results != null && results > 0;

    if (changed && hasResults) {
      return TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'búsqueda verificada: pantalla cambió y $results resultado(s)',
      );
    }
    if (changed || hasResults) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'evidencia parcial de búsqueda (cambio de pantalla o resultados)',
      );
    }
    return const TaskStepResult(
      status: TaskStepStatus.completedUnverified,
      reason: 'submit aceptado; sin cambio detectable de pantalla',
    );
  }
}

class SelectResultHandler implements TaskStepHandler {
  const SelectResultHandler();

  @override
  String get semanticAction => 'selectResult';

  @override
  Future<TaskStepResult> handle(StepContext ctx) async {
    final resolve = ctx.env.resolveResult;
    final tap = ctx.env.tap;
    if (resolve == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de resolución/tap de resultados',
        failureKind: TaskFailureKind.terminal,
      );
    }

    final goal = ctx.goal;
    final ResultTarget target;
    if (goal.resultOrdinal != null) {
      target = ResultOrdinal(goal.resultOrdinal!);
    } else if (goal.resultText.isNotEmpty) {
      target = ResultText(goal.resultText);
    } else {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin ordinal ni texto de resultado',
        failureKind: TaskFailureKind.terminal,
      );
    }

    final resolution = await resolve(target);
    if (resolution == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin snapshot de pantalla para resolver resultados',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (resolution is ResultNotFound) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'resultado no encontrado en pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (resolution is ResultAmbiguous) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            'resultado ambiguo entre ${resolution.candidates.length} coincidencias (clarificación)',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final candidate = (resolution as ResultResolved).candidate;

    final readText = ctx.env.readVisibleText;
    final before = readText != null ? await readText() : null;

    final ok = await tap(candidate.selector);
    if (!ok) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'tap de resultado devolvió false',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    // Verificación de apertura — "tap aceptado" NO es apertura.
    final after = readText != null ? await readText() : null;
    final changed = before != null && after != null && before != after;
    final title = candidate.title.toLowerCase();
    final contentObserved =
        after != null && title.isNotEmpty && after.toLowerCase().contains(title);

    if (changed && contentObserved) {
      return const TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'resultado abierto: contenido objetivo observado',
      );
    }
    if (changed) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'pantalla cambió (evidencia parcial de apertura)',
      );
    }
    return const TaskStepResult(
      status: TaskStepStatus.completedUnverified,
      reason: 'tap aceptado; sin cambio detectable de pantalla',
    );
  }
}
