part of 'task_orchestrator.dart';

extension _TaskOrchestratorNavigation on TaskOrchestrator {
  Future<String?> _resolveInputWithSettle(
    Future<String?> Function(String kind) resolveInput,
  ) async {
    const waits = <Duration>[
      Duration.zero,
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(milliseconds: 1000),
    ];
    for (final wait in waits) {
      if (wait != Duration.zero) await Future<void>.delayed(wait);
      final input = await resolveInput('search');
      if (input != null && input.isNotEmpty) return input;
    }
    return null;
  }

  /// Intento único de saltar un anuncio tras abrir un video. Espera el
  /// intervalo típico de aparición y, si el botón es observable, lo toca.
  /// Sin botón → no-op honesto (el video sigue reproduciéndose).
  Future<void> _skipAdIfPresent() async {
    final resolveAction = _resolveActionSurface;
    final tap = _tap;
    if (resolveAction == null || tap == null) return;
    await Future<void>.delayed(const Duration(seconds: 3));
    final skip = await resolveAction('skipAd');
    if (skip == null || skip.isEmpty) return;
    await tap(skip, semanticAction: 'selectResult');
  }

  TaskStepResult _stepFromAction(
    TaskActionResult action, {
    required String completedReason,
    TaskValue? output,
    bool recoverable = false,
  }) {
    return switch (action.status) {
      TaskActionStatus.completed => TaskStepResult(
        status: TaskStepStatus.completed,
        reason: completedReason,
        output: output,
      ),
      TaskActionStatus.completedUnverified => TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: action.reason,
        output: output,
      ),
      TaskActionStatus.needsConfirmation => TaskStepResult(
        status: TaskStepStatus.needsConfirmation,
        reason: action.reason,
        failureKind: TaskFailureKind.terminal,
        pendingActionSignature: action.actionSignature,
      ),
      TaskActionStatus.denied => TaskStepResult(
        status: TaskStepStatus.denied,
        reason: action.reason,
        failureKind: TaskFailureKind.terminal,
      ),
      TaskActionStatus.outcomeUnknown => TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason: action.reason,
        failureKind: TaskFailureKind.terminal,
      ),
      TaskActionStatus.failed => TaskStepResult(
        status: TaskStepStatus.failed,
        reason: action.reason,
        failureKind: recoverable
            ? TaskFailureKind.recoverable
            : TaskFailureKind.terminal,
      ),
    };
  }

  String _planSignature(TaskPlan plan, List<TaskStep> ordered) =>
      canonicalFingerprint({
        'goal': plan.goal,
        'steps': [
          for (var index = 0; index < ordered.length; index++)
            {
              'index': index,
              'id': ordered[index].id,
              'action': ordered[index].semanticAction,
              'dependencies': ordered[index].dependencies,
              'bindings': {
                for (final entry in ordered[index].inputBindings.entries)
                  entry.key: entry.value.source.value,
              },
              'evidence': {
                for (final entry in ordered[index].dependencyEvidence.entries)
                  entry.key: entry.value.name,
              },
            },
        ],
      });

  AutomationConversationSnapshot _parseGoal(String goal) {
    final g = goal.toLowerCase();

    // Intención de mensaje (app/recipient/message) vía el parser ÚNICO.
    final intent = const MessageIntentParser().parse(goal);
    const genericParser = GenericUiIntentParser();
    final genericUi = genericParser.parse(goal);
    final genericFill = genericParser.parseFill(goal);
    final genericCompose = genericParser.parseCompose(goal);
    final search = genericParser.parseSearch(goal);

    // Cada parser conserva intención; package y superficies se resuelven
    // después contra inventario/Accessibility. La búsqueda comparte exactamente
    // la misma gramática que TaskPlanner, incluidas apps de varias palabras.
    var appName = intent.app;
    if (genericUi.app.isNotEmpty) appName = genericUi.app;
    if (genericFill.app.isNotEmpty) appName = genericFill.app;
    if (genericCompose.app.isNotEmpty) appName = genericCompose.app;
    if (search.app.isNotEmpty) appName = search.app;

    // T2.9-select: ordinal ("segundo") o texto ("que dice X") del resultado.
    final resultOrdinal = _parseResultOrdinal(g);
    final resultText = _parseResultText(goal);

    return AutomationConversationSnapshot(
      appName: appName,
      target: intent.recipient,
      draft: intent.message,
      query: search.query,
      resultOrdinal: resultOrdinal,
      resultText: resultText,
      uiActionTarget: genericCompose.actionTarget,
      uiTarget: genericCompose.fieldTarget.isNotEmpty
          ? genericCompose.fieldTarget
          : genericFill.target.isNotEmpty
          ? genericFill.target
          : genericUi.target,
      uiText: genericCompose.text.isNotEmpty
          ? genericCompose.text
          : genericFill.text,
    );
  }

  /// Ordinal determinista de resultado: "primero"=1, "segundo"=2, "resultado 3",
  /// "el de arriba"=1. null = sin ordinal explícito.
  int? _parseResultOrdinal(String g) {
    const words = {
      'primero': 1,
      'primer': 1,
      'primera': 1,
      'segundo': 2,
      'segunda': 2,
      'tercero': 3,
      'tercer': 3,
      'tercera': 3,
      'cuarto': 4,
      'cuarta': 4,
      'quinto': 5,
      'quinta': 5,
    };
    for (final e in words.entries) {
      if (g.contains(e.key)) return e.value;
    }
    final nMatch = RegExp(r'resultado\s+(\d+)').firstMatch(g);
    if (nMatch != null) return int.tryParse(nMatch.group(1)!);
    if (g.contains('de arriba')) return 1;
    return null;
  }

  /// Texto objetivo del resultado: "que dice X" / "dice X". '' = sin texto.
  /// Se recorta del ORIGINAL para conservar el case ("NanoRuntime").
  String _parseResultText(String goal) {
    final m = RegExp(r'dice\s+(.+)$', caseSensitive: false).firstMatch(goal);
    return m?.group(1)?.trim() ?? '';
  }
}
