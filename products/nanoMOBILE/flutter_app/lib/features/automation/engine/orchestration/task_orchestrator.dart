/// A15.0 — TaskOrchestrator: ejecuta un TaskPlan paso a paso, transportando
/// TaskValues TIPADOS entre dominios.
///
/// NO es un segundo AutomationCoordinator ni un workflow engine libre. Cada paso
/// es semántico; la ejecución efectiva se delega a fuentes inyectadas (que a su
/// vez pasan por el pipeline Candidate-First + governance + verificación).
library;

import '../notifications/notification_object.dart';
import '../notifications/observed_data_extractor.dart';
import '../perception/search_result_resolver.dart';
import '../planning/message_intent_parser.dart';
import '../governance/action_confirmation.dart';
import '../voice/execution_cancellation.dart';
import 'commit_guard.dart';
import 'execution_journal.dart';
import 'task_plan.dart';

typedef TaskOpenUrl =
    Future<TaskActionResult> Function(
      String url, {
      String? confirmedActionSignature,
    });
typedef TaskWriteFile =
    Future<TaskActionResult> Function(
      String path,
      String content, {
      String? confirmedActionSignature,
    });
typedef TaskLaunchApp =
    Future<TaskActionResult> Function(
      String appName, {
      String? confirmedActionSignature,
    });
typedef TaskTap =
    Future<TaskActionResult> Function(
      String selector, {
      String? confirmedActionSignature,
    });
typedef TaskWriteText =
    Future<TaskActionResult> Function(
      String selector,
      String text, {
      String? confirmedActionSignature,
    });

class TaskOrchestrator {
  TaskOrchestrator({
    required Future<List<dynamic>> Function() listNotifications,
    required TaskOpenUrl openUrl,
    required TaskWriteFile writeFile,
    TaskLaunchApp? launchApp,
    TaskTap? tap,
    TaskWriteText? writeText,
    Future<String?> Function()? resolveInputSurface,
    Future<String?> Function(String kind)? resolveInputSurfaceFor,
    Future<String?> Function(String kind)? resolveActionSurface,
    Future<ResultResolution?> Function(ResultTarget target)? resolveResult,
    Future<String?> Function()? readVisibleText,
    Future<int?> Function()? detectSearchResults,
    CommitGuard? commitGuard,
    ExecutionJournal? journal,
    this.maxAttemptsPerStep = 2,
    this.maxReplansPerTask = 2,
  }) : _listNotifications = listNotifications,
       _openUrl = openUrl,
       _writeFile = writeFile,
       _launchApp = launchApp,
       _tap = tap,
       _writeText = writeText,
       _resolveInputSurfaceFor =
           resolveInputSurfaceFor ??
           (resolveInputSurface == null ? null : (_) => resolveInputSurface()),
       _resolveActionSurface = resolveActionSurface,
       _resolveResult = resolveResult,
       _readVisibleText = readVisibleText,
       _detectSearchResults = detectSearchResults,
       _commitGuard = commitGuard,
       _journal = journal;

  final Future<List<dynamic>> Function() _listNotifications;
  final TaskOpenUrl _openUrl;
  final TaskWriteFile _writeFile;

  /// A15.4 — fuentes UI (delegan al dispatcher/ScreenGraph).
  final TaskLaunchApp? _launchApp;
  final TaskTap? _tap;
  final TaskWriteText? _writeText;

  /// Variante con intención explícita (`message`/`search`). La usan los flujos
  /// que mutan un campo para no confundir compositor y buscador.
  final Future<String?> Function(String kind)? _resolveInputSurfaceFor;
  final Future<String?> Function(String kind)? _resolveActionSurface;

  /// T2.9-select — resolución grounded de un resultado observado (ordinal/texto).
  /// null = sin fuente de resolución; el paso devuelve needsMoreEvidence.
  final Future<ResultResolution?> Function(ResultTarget target)? _resolveResult;

  /// T2.9-verify — texto visible de la pantalla (fingerprint de snapshot, para
  /// detectar cambio PRE/POST). null = sin observación → completedUnverified.
  final Future<String?> Function()? _readVisibleText;

  /// T2.9-verify — nº de resultados de búsqueda detectados en pantalla.
  /// null = sin observación.
  final Future<int?> Function()? _detectSearchResults;
  final CommitGuard? _commitGuard;
  final ExecutionJournal? _journal;

  /// A15.1 — presupuesto de recuperación acotado.
  final int maxAttemptsPerStep;
  final int maxReplansPerTask;

  /// Ejecuta el plan en orden topológico con recuperación ACOTADA (A15.1).
  /// Un paso no-completado detiene los dependientes. Los pasos fallidos
  /// recuperables se reintentan hasta el presupuesto; un reintento con el MISMO
  /// motivo (sin progreso) se detiene para evitar loops.
  Future<List<TaskStepResult>> run(
    TaskPlan plan, {
    ExecutionCancellationToken? cancel,
    ActionConfirmation? confirmation,
    String? executionId,
  }) async {
    final invalid = plan.validate();
    if (invalid != null) {
      return [TaskStepResult(status: TaskStepStatus.failed, reason: invalid)];
    }

    final values = <TaskValueId, TaskValue>{};
    final results = <TaskStepResult>[];
    final resultsByStep = <String, TaskStepResult>{};
    var replans = 0;
    final goalCtx = _parseGoal(plan.goal);

    final ordered = plan.ordered;
    final planSignature = _planSignature(plan, ordered);
    final runId = executionId ?? confirmation?.executionId ?? _newRunId();
    final goalFingerprint = canonicalFingerprint(plan.goal);
    final journal = _journal;
    if (journal != null) {
      await journal.recoverInterrupted();
      final unresolved = (await journal.all()).where(
        (entry) =>
            entry.goalFingerprint == goalFingerprint &&
            entry.irreversible &&
            entry.status == ExecutionJournalStatus.outcomeUnknown,
      );
      if (unresolved.any((entry) => entry.runId != runId)) {
        return const [
          TaskStepResult(
            status: TaskStepStatus.outcomeUnknown,
            reason:
                'existe un commit irreversible interrumpido para este objetivo; '
                'se requiere reconciliación antes de repetir',
            failureKind: TaskFailureKind.terminal,
          ),
        ];
      }
    }
    final validConfirmation =
        confirmation != null &&
        confirmation.stepIndex >= 0 &&
        confirmation.stepIndex < ordered.length &&
        confirmation.consumeIfAuthorizes(
          executionId: runId,
          planSignature: planSignature,
          stepIndex: confirmation.stepIndex,
          stepId: ordered[confirmation.stepIndex].id,
          actionSignature: confirmation.actionSignature,
        );
    final startIndex = validConfirmation ? confirmation.stepIndex : 0;
    if (journal != null && ordered.isNotEmpty) {
      final first = ordered[startIndex];
      await journal.save(
        ExecutionJournalEntry(
          runId: runId,
          planSignature: planSignature,
          goalFingerprint: goalFingerprint,
          currentStep: startIndex,
          stepId: first.id,
          status: ExecutionJournalStatus.planned,
          irreversible: _isIrreversible(first),
          actionSignature: _semanticActionSignature(
            planSignature: planSignature,
            step: first,
            goal: plan.goal,
          ),
          verificationState: 'plan validado; acción aún no iniciada',
          timestamp: DateTime.now().toUtc(),
        ),
      );
    }

    // Al reanudar no se repiten acciones previas. Solo se reconstruyen valores
    // de pasos observacionales/puros necesarios por el paso confirmado.
    for (var index = 0; index < startIndex; index++) {
      final prior = ordered[index];
      if (prior.semanticAction != 'readNotification' &&
          prior.semanticAction != 'extractUrl') {
        continue;
      }
      final rebuilt = await _runStep(prior, values, goalCtx);
      results.add(rebuilt);
      resultsByStep[prior.id] = rebuilt;
      if (rebuilt.isFailure) return results;
      if (prior.produces != null && rebuilt.output != null) {
        values[prior.produces!] = rebuilt.output!;
      }
    }

    for (var stepIndex = startIndex; stepIndex < ordered.length; stepIndex++) {
      final step = ordered[stepIndex];
      final insufficient = _insufficientDependency(step, resultsByStep);
      if (insufficient != null) {
        final blocked = TaskStepResult(
          status: TaskStepStatus.needsMoreEvidence,
          reason: insufficient,
          failureKind: TaskFailureKind.terminal,
        );
        results.add(blocked);
        resultsByStep[step.id] = blocked;
        break;
      }
      // A16 — cancelación cooperativa: aborta ANTES del siguiente paso.
      try {
        cancel?.throwIfCancelled();
      } on ExecutionCancelled {
        results.add(
          const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'cancelado por el usuario',
            failureKind: TaskFailureKind.terminal,
          ),
        );
        break;
      }
      final irreversible = _isIrreversible(step);
      final semanticActionSignature = _semanticActionSignature(
        planSignature: planSignature,
        step: step,
        goal: plan.goal,
      );
      await journal?.save(
        ExecutionJournalEntry(
          runId: runId,
          planSignature: planSignature,
          goalFingerprint: goalFingerprint,
          currentStep: stepIndex,
          stepId: step.id,
          status: ExecutionJournalStatus.executing,
          irreversible: irreversible,
          actionSignature: semanticActionSignature,
          verificationState: 'acción iniciada',
          timestamp: DateTime.now().toUtc(),
        ),
      );
      var result = await _runStep(
        step,
        values,
        goalCtx,
        confirmedActionSignature:
            validConfirmation && stepIndex == confirmation.stepIndex
            ? confirmation.actionSignature
            : null,
      );
      if (result.status == TaskStepStatus.needsConfirmation &&
          result.pendingActionSignature != null) {
        result = TaskStepResult(
          status: result.status,
          reason: result.reason,
          failureKind: result.failureKind,
          pendingActionSignature: result.pendingActionSignature,
          confirmation: ActionConfirmation(
            executionId: runId,
            planSignature: planSignature,
            stepIndex: stepIndex,
            stepId: step.id,
            actionSignature: result.pendingActionSignature!,
          ),
        );
      }
      await journal?.save(
        ExecutionJournalEntry(
          runId: runId,
          planSignature: planSignature,
          goalFingerprint: goalFingerprint,
          currentStep: stepIndex,
          stepId: step.id,
          status: _journalStatus(result.status),
          irreversible: irreversible,
          actionSignature: semanticActionSignature,
          verificationState: result.reason,
          timestamp: DateTime.now().toUtc(),
          pendingConfirmation: result.confirmation,
        ),
      );
      var attempts = 1;

      while (!result.isCompleted &&
          result.isRecoverable &&
          _mayReplay(step) &&
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
      resultsByStep[step.id] = result;
      if (result.isFailure) break;
      if (step.produces != null && result.output != null) {
        values[step.produces!] = result.output!;
      }
    }
    return results;
  }

  String? _insufficientDependency(
    TaskStep step,
    Map<String, TaskStepResult> results,
  ) {
    for (final dependency in step.dependencies) {
      final observed = results[dependency];
      // En una reanudación exacta, los pasos previos no se repiten. Su estado
      // se vuelve a comprobar por el context lock del commit irreversible.
      if (observed == null) continue;
      final required = step.evidenceRequiredFrom(dependency);
      final actual = observed.evidence;
      if (actual == null ||
          (required == RequiredEvidence.verified &&
              actual != RequiredEvidence.verified)) {
        return 'La dependencia "$dependency" no aporta evidencia '
            '${required.name}; se bloquea ${step.semanticAction}.';
      }
    }
    return null;
  }

  static int _runSequence = 0;
  static String _newRunId() =>
      'task-${DateTime.now().microsecondsSinceEpoch}-${++_runSequence}';

  String _semanticActionSignature({
    required String planSignature,
    required TaskStep step,
    required String goal,
  }) => canonicalFingerprint({
    'plan': planSignature,
    'step': step.id,
    'action': step.semanticAction,
    'goal': goal,
  });

  /// Repetir una acción solo es seguro para operaciones que reemplazan un
  /// estado local conocido. Navegar, abrir recursos o enviar mensajes puede
  /// haber surtido efecto aunque su verificación posterior haya sido incierta;
  /// esos pasos se detienen y requieren una nueva decisión humana.
  bool _mayReplay(TaskStep step) => switch (step.semanticAction) {
    'writeFile' || 'writeMessage' || 'writeQuery' => true,
    _ => false,
  };

  bool _isIrreversible(TaskStep step) => switch (step.semanticAction) {
    'sendMessage' => true,
    _ => false,
  };

  ExecutionJournalStatus _journalStatus(TaskStepStatus status) =>
      switch (status) {
        TaskStepStatus.completed => ExecutionJournalStatus.verified,
        TaskStepStatus.completedUnverified =>
          ExecutionJournalStatus.completedUnverified,
        TaskStepStatus.needsConfirmation =>
          ExecutionJournalStatus.waitingConfirmation,
        TaskStepStatus.outcomeUnknown => ExecutionJournalStatus.outcomeUnknown,
        TaskStepStatus.denied => ExecutionJournalStatus.cancelled,
        TaskStepStatus.needsMoreEvidence ||
        TaskStepStatus.failed => ExecutionJournalStatus.failed,
      };

  Future<TaskStepResult> _runStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values,
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
    switch (step.semanticAction) {
      case 'readNotification':
        return _readNotification();
      case 'extractUrl':
        return _extractUrl(step, values);
      case 'writeFile':
        return _writeFileStep(
          step,
          values,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'openUrl':
        return _openUrlStep(
          step,
          values,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'openApp':
        return _openApp(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'openConversation':
        return _openConversation(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'writeMessage':
        return _writeMessage(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'sendMessage':
        return _sendMessage(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'writeQuery':
        return _writeQuery(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'submitSearch':
        return _submitSearch(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'selectResult':
        return _selectResult(
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
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
    Map<TaskValueId, TaskValue> values, {
    String? confirmedActionSignature,
  }) async {
    final binding = step.inputBindings['content'];
    final value = binding == null ? null : values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para escribir',
      );
    }
    const path = '/root/nano_observed_link.txt';
    final action = await _writeFile(
      path,
      value.url,
      confirmedActionSignature: confirmedActionSignature,
    );
    return _stepFromAction(
      action,
      completedReason: 'URL escrita a archivo',
      output: const FilePathValue(path),
      recoverable: true,
    );
  }

  Future<TaskStepResult> _openUrlStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values, {
    String? confirmedActionSignature,
  }) async {
    final binding = step.inputBindings['url'];
    final value = binding == null ? null : values[binding.source];
    if (value is! UrlValue) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin URL para abrir',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await _openUrl(
      value.url,
      confirmedActionSignature: confirmedActionSignature,
    );
    return _stepFromAction(
      action,
      completedReason: 'URL abierta',
      recoverable: true,
    );
  }

  // ── A15.4 — pasos UI (delegan al dispatcher/ScreenGraph) ──────────────────

  Future<TaskStepResult> _openApp(
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
    // T2.8: si el objetivo no nombra la app ("escríbele a Juan"), derivarla de
    // la notificación activa cuyo sender/conversación matchea el target. El
    // package sale de la evidencia real, nunca se inventa. Sin app derivable →
    // needsMoreEvidence honesto (el humano/planner aclara en qué app).
    final app = await _resolveMessagingApp(goal);
    if (app == null || app.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin app en el objetivo ni en notificaciones',
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
    final action = await launch(
      app,
      confirmedActionSignature: confirmedActionSignature,
    );
    return _stepFromAction(
      action,
      completedReason: 'app abierta',
      recoverable: true,
    );
  }

  /// Deriva la app de mensajería a abrir: el nombre explícito del objetivo si
  /// existe; si no, el packageName de la notificación activa que matchea el
  /// target (sender/conversationTitle/title). null = sin evidencia.
  Future<String?> _resolveMessagingApp(_GoalContext goal) async {
    if (goal.appName.isNotEmpty) return goal.appName;
    if (goal.target.isEmpty) return null;

    final raw = await _listNotifications();
    for (final m in raw.whereType<Map>()) {
      final n = NotificationObject.fromMap(m.cast<dynamic, dynamic>());
      if (n.packageName.isEmpty) continue;
      if (n.matchesRecipient(goal.target)) return n.packageName;
    }
    return null;
  }

  Future<TaskStepResult> _openConversation(
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
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

    // T2.9 — ruta directa: la conversación ya está visible como texto.
    final direct = await tap(
      'text=${goal.target}',
      confirmedActionSignature: confirmedActionSignature,
    );
    if (direct.completed) {
      return const TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'conversación abierta',
      );
    }
    if (!direct.mayFallback) {
      return _stepFromAction(
        direct,
        completedReason: 'conversación abierta',
        recoverable: true,
      );
    }

    // T2.9 — fallback de búsqueda: localizar la conversación vía la superficie
    // de búsqueda de la app (icono → campo → escribir → resultado). Sin fuentes
    // de búsqueda se reporta fallo recoverable, nunca se inventa nada.
    final resolveSearchInput = _resolveInputSurfaceFor;
    final resolveAction = _resolveActionSurface;
    final write = _writeText;
    if (resolveSearchInput == null || resolveAction == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'conversación no visible y sin búsqueda disponible',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    // 1. Si ya hay un campo de búsqueda semántico, usarlo. De lo contrario,
    // abrirlo y comprobar que apareció antes de escribir. No se degrada al
    // compositor: eso podría convertir el nombre del contacto en un mensaje.
    var input = await resolveSearchInput('search');
    if (input == null || input.isEmpty) {
      final searchIcon = await resolveAction('search');
      if (searchIcon == null || searchIcon.isEmpty) {
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'sin icono ni campo de búsqueda identificable',
          failureKind: TaskFailureKind.recoverable,
        );
      }
      final openSearch = await tap(
        searchIcon,
        confirmedActionSignature: confirmedActionSignature,
      );
      if (!openSearch.completed) {
        return _stepFromAction(
          openSearch,
          completedReason: 'búsqueda de conversaciones abierta',
          recoverable: true,
        );
      }
      input = await resolveSearchInput('search');
    }

    // 2. Escribir el target en el campo de búsqueda ya observado.
    if (input == null || input.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'sin campo de búsqueda para localizar la conversación',
        failureKind: TaskFailureKind.recoverable,
      );
    }
    final written = await write(
      input,
      goal.target,
      confirmedActionSignature: confirmedActionSignature,
    );
    if (!written.completed) {
      return _stepFromAction(
        written,
        completedReason: 'target escrito en la búsqueda',
        recoverable: true,
      );
    }

    // 3. Tocar el resultado. `editable=false` excluye el propio campo de
    // búsqueda (que ahora contiene el target) y apunta al item de resultado.
    final resultTap = await tap(
      'text=${goal.target};editable=false',
      confirmedActionSignature: confirmedActionSignature,
    );
    if (resultTap.completed) {
      return const TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'conversación abierta vía búsqueda',
      );
    }
    return _stepFromAction(
      resultTap,
      completedReason: 'conversación abierta vía búsqueda',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _writeMessage(
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
    if (goal.draft.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin borrador de mensaje',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolve = _resolveInputSurfaceFor;
    final write = _writeText;
    if (resolve == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación de pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    // Resolver el compositor REAL en lugar de escribir en un selector vacío.
    final selector = await resolve('message');
    if (selector == null || selector.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin superficie de entrada editable visible',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await write(
      selector,
      goal.draft,
      confirmedActionSignature: confirmedActionSignature,
    );
    return _stepFromAction(
      action,
      completedReason: 'mensaje escrito en superficie editable',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _sendMessage(
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
    final guard = _commitGuard;
    final tap = _tap;
    if (guard == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin ContextGuard/observación para envío irreversible',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final captured = await guard.capture(
      conversation: goal.target,
      draft: goal.draft,
    );
    if (!captured.ready) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'context lock rechazó el envío: ${captured.reason}',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final context = captured.context!;
    final locked = await guard.revalidate(context);
    if (!locked.ready) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'contexto cambió antes de enviar: ${locked.reason}',
        failureKind: TaskFailureKind.terminal,
      );
    }

    // ACT ONCE. Desde este punto nunca se reintenta el tap automáticamente.
    final action = await tap(
      context.sendSelector,
      confirmedActionSignature: confirmedActionSignature,
    );
    if (!action.completed) {
      return _stepFromAction(
        action,
        completedReason: 'botón de envío pulsado',
        recoverable: false,
      );
    }
    final evidence = await guard.verifyAfterDispatch(context);
    return switch (evidence.status) {
      SendEvidenceStatus.localSendVerified => TaskStepResult(
        status: TaskStepStatus.completed,
        reason:
            'envío local verificado: ${evidence.reason}; entrega remota desconocida',
      ),
      SendEvidenceStatus.dispatchedUnverified => TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: evidence.reason,
      ),
      SendEvidenceStatus.outcomeUnknown ||
      SendEvidenceStatus.contextChanged ||
      SendEvidenceStatus.incompleteEvidence => TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason: evidence.reason,
        failureKind: TaskFailureKind.terminal,
      ),
    };
  }

  // ── T2.9 — búsqueda genérica dentro de una app ─────────────────────────────

  Future<TaskStepResult> _writeQuery(
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
    if (goal.query.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin query de búsqueda',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolveInput = _resolveInputSurfaceFor;
    final write = _writeText;
    if (resolveInput == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación',
        failureKind: TaskFailureKind.terminal,
      );
    }

    var input = await resolveInput('search');
    if (input == null || input.isEmpty) {
      // No hay campo visible: abrir la búsqueda tocando el icono (si existe).
      final resolveAction = _resolveActionSurface;
      final tap = _tap;
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
      final openSearch = await tap(
        icon,
        confirmedActionSignature: confirmedActionSignature,
      );
      if (!openSearch.completed) {
        return _stepFromAction(
          openSearch,
          completedReason: 'búsqueda abierta',
          recoverable: true,
        );
      }
      input = await resolveInput('search');
      if (input == null || input.isEmpty) {
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'el icono de búsqueda no abrió un campo editable',
          failureKind: TaskFailureKind.recoverable,
        );
      }
    }

    final action = await write(
      input,
      goal.query,
      confirmedActionSignature: confirmedActionSignature,
    );
    return _stepFromAction(
      action,
      completedReason: 'query escrita en el campo de búsqueda',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _submitSearch(
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
    final resolveAction = _resolveActionSurface;
    final tap = _tap;
    if (resolveAction == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'query escrita; sin fuente para submit',
      );
    }
    final action = await resolveAction('search');
    if (action == null || action.isEmpty) {
      // Sin botón de submit: búsqueda en vivo (algunas apps buscan al escribir).
      return const TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: 'query escrita; sin botón de submit (búsqueda en vivo)',
      );
    }

    // PRE: snapshot A (fingerprint de texto visible).
    final readText = _readVisibleText;
    final detect = _detectSearchResults;
    final before = readText != null ? await readText() : null;

    final submitted = await tap(
      action,
      confirmedActionSignature: confirmedActionSignature,
    );
    if (!submitted.completed) {
      return _stepFromAction(
        submitted,
        completedReason: 'búsqueda enviada',
        recoverable: true,
      );
    }

    // POST: SearchResultVerification — "tecla aceptada" NO es búsqueda.
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
        reason:
            'evidencia parcial de búsqueda (cambio de pantalla o resultados)',
      );
    }
    return const TaskStepResult(
      status: TaskStepStatus.completedUnverified,
      reason: 'submit aceptado; sin cambio detectable de pantalla',
    );
  }

  // ── T2.9-select — selección semántica de resultado observado ───────────────

  Future<TaskStepResult> _selectResult(
    _GoalContext goal, {
    String? confirmedActionSignature,
  }) async {
    final resolve = _resolveResult;
    final tap = _tap;
    if (resolve == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de resolución/tap de resultados',
        failureKind: TaskFailureKind.terminal,
      );
    }

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
    if (resolution is ResultIncompleteEvidence) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            'snapshot incompleto: ${resolution.observed.length} resultado(s) '
            'observados no prueban una selección única',
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

    // PRE: snapshot A (fingerprint de texto visible).
    final readText = _readVisibleText;
    final before = readText != null ? await readText() : null;

    final selected = await tap(
      candidate.selector,
      confirmedActionSignature: confirmedActionSignature,
    );
    if (!selected.completed) {
      return _stepFromAction(
        selected,
        completedReason: 'resultado seleccionado',
        recoverable: true,
      );
    }

    // POST: SearchResultVerification de apertura — "tap aceptado" NO es apertura.
    final after = readText != null ? await readText() : null;
    final changed = before != null && after != null && before != after;
    final title = candidate.title.toLowerCase();
    final contentObserved =
        after != null &&
        title.isNotEmpty &&
        after.toLowerCase().contains(title);

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

  _GoalContext _parseGoal(String goal) {
    final g = goal.toLowerCase();

    // Intención de mensaje (app/recipient/message) vía el parser ÚNICO.
    final intent = const MessageIntentParser().parse(goal);

    // App: intent.app ("abre X"/"ve a X") o "… en X" (búsqueda "busca Y en X").
    final enAppMatch = RegExp(r'en\s+(\w+)\s*$').firstMatch(g);
    var appName = intent.app;
    if (enAppMatch != null) appName = enAppMatch.group(1)!;

    // Query: "busca X…" — se recorta del ORIGINAL para conservar el case del
    // término de búsqueda ("NanoRuntime" no debe quedar "nanoruntime").
    var query = '';
    final buscaIdx = g.indexOf('busca');
    if (buscaIdx >= 0) {
      query = goal.substring(buscaIdx + 'busca'.length).trim();
      if (enAppMatch != null) {
        query = query
            .replaceAll(RegExp(r'\s+en\s+\w+\s*$', caseSensitive: false), '')
            .trim();
      }
    }

    // T2.9-select: ordinal ("segundo") o texto ("que dice X") del resultado.
    final resultOrdinal = _parseResultOrdinal(g);
    final resultText = _parseResultText(goal);

    return _GoalContext(
      appName: appName,
      target: intent.recipient,
      draft: intent.message,
      query: query,
      resultOrdinal: resultOrdinal,
      resultText: resultText,
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

class _GoalContext {
  final String appName;
  final String target;
  final String draft;

  /// T2.9 — query de búsqueda ("abre YouTube y busca X").
  final String query;

  /// T2.9-select — ordinal del resultado (null = no expresado).
  final int? resultOrdinal;

  /// T2.9-select — texto objetivo del resultado ('' = no expresado).
  final String resultText;

  const _GoalContext({
    this.appName = '',
    this.target = '',
    this.draft = '',
    this.query = '',
    this.resultOrdinal,
    this.resultText = '',
  });
}
