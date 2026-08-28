/// A15.0 — TaskOrchestrator: ejecuta un TaskPlan paso a paso, transportando
/// TaskValues TIPADOS entre dominios.
///
/// NO es un segundo AutomationCoordinator ni un workflow engine libre. Cada paso
/// es semántico; la ejecución efectiva se delega a fuentes inyectadas (que a su
/// vez pasan por el pipeline Candidate-First + governance + verificación).
library;

import '../notifications/notification_object.dart';
import '../notifications/observed_data_extractor.dart';
import '../planning/message_intent_parser.dart';
import '../voice/execution_cancellation.dart';
import 'task_plan.dart';

class TaskOrchestrator {
  TaskOrchestrator({
    required Future<List<dynamic>> Function() listNotifications,
    required Future<bool> Function(String url) openUrl,
    required Future<bool> Function(String path, String content) writeFile,
    Future<bool> Function(String appName)? launchApp,
    Future<bool> Function(String selector)? tap,
    Future<bool> Function(String selector, String text)? writeText,
    Future<String?> Function()? resolveInputSurface,
    Future<String?> Function(String kind)? resolveActionSurface,
    Future<String?> Function()? observeInputText,
    this.maxAttemptsPerStep = 2,
    this.maxReplansPerTask = 2,
  }) : _listNotifications = listNotifications,
       _openUrl = openUrl,
       _writeFile = writeFile,
       _launchApp = launchApp,
       _tap = tap,
       _writeText = writeText,
       _resolveInputSurface = resolveInputSurface,
       _resolveActionSurface = resolveActionSurface,
       _observeInputText = observeInputText;

  final Future<List<dynamic>> Function() _listNotifications;
  final Future<bool> Function(String url) _openUrl;
  final Future<bool> Function(String path, String content) _writeFile;

  /// A15.4 — fuentes UI (delegan al dispatcher/ScreenGraph).
  final Future<bool> Function(String appName)? _launchApp;
  final Future<bool> Function(String selector)? _tap;
  final Future<bool> Function(String selector, String text)? _writeText;

  /// T2.0 — resolución grounded de superficies UI (input editable y botón de
  /// acción). null = fuente no conectada (tests aislados o perfil sin
  /// accesibilidad): el paso devuelve needsMoreEvidence, nunca inventa.
  final Future<String?> Function()? _resolveInputSurface;
  final Future<String?> Function(String kind)? _resolveActionSurface;

  /// T2.7 — lectura del texto ACTUAL de la superficie de entrada (para verificar
  /// el envío observando que el composer quedó vacío). null = sin observación;
  /// el paso degrada a completedUnverified (nunca afirma envío sin evidencia).
  final Future<String?> Function()? _observeInputText;

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
  }) async {
    final invalid = plan.validate();
    if (invalid != null) {
      return [TaskStepResult(status: TaskStepStatus.failed, reason: invalid)];
    }

    final values = <TaskValueId, TaskValue>{};
    final results = <TaskStepResult>[];
    var replans = 0;
    final goalCtx = _parseGoal(plan.goal);

    for (final step in plan.ordered) {
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
        return _sendMessage(goal);
      case 'writeQuery':
        return _writeQuery(goal);
      case 'submitSearch':
        return _submitSearch(goal);
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
    final ok = await launch(app);
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

    // T2.9 — ruta directa: la conversación ya está visible como texto.
    if (await tap('text=${goal.target}')) {
      return const TaskStepResult(
        status: TaskStepStatus.completed,
        reason: 'conversación abierta',
      );
    }

    // T2.9 — fallback de búsqueda: localizar la conversación vía la superficie
    // de búsqueda de la app (icono → campo → escribir → resultado). Sin fuentes
    // de búsqueda se reporta fallo recoverable, nunca se inventa nada.
    final resolveInput = _resolveInputSurface;
    final resolveAction = _resolveActionSurface;
    final write = _writeText;
    if (resolveInput == null || resolveAction == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'conversación no visible y sin búsqueda disponible',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    // 1. Si hay un icono de búsqueda, tócalo para abrir el campo.
    final searchIcon = await resolveAction('search');
    if (searchIcon != null && searchIcon.isNotEmpty) {
      await tap(searchIcon);
    }

    // 2. Escribir el target en el campo de búsqueda.
    final input = await resolveInput();
    if (input == null || input.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'sin campo de búsqueda para localizar la conversación',
        failureKind: TaskFailureKind.recoverable,
      );
    }
    if (!await write(input, goal.target)) {
      return const TaskStepResult(
        status: TaskStepStatus.failed,
        reason: 'no se pudo escribir el target en la búsqueda',
        failureKind: TaskFailureKind.recoverable,
      );
    }

    // 3. Tocar el resultado. `editable=false` excluye el propio campo de
    // búsqueda (que ahora contiene el target) y apunta al item de resultado.
    if (await tap('text=${goal.target};editable=false')) {
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

  Future<TaskStepResult> _writeMessage(_GoalContext goal) async {
    if (goal.draft.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin borrador de mensaje',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolve = _resolveInputSurface;
    final write = _writeText;
    if (resolve == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación de pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    // T2.0: resolver la superficie de entrada editable REAL (composer/buscador)
    // en lugar de escribir en un selector vacío.
    final selector = await resolve();
    if (selector == null || selector.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin superficie de entrada editable visible',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final ok = await write(selector, goal.draft);
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

  Future<TaskStepResult> _sendMessage(_GoalContext goal) async {
    final resolve = _resolveActionSurface;
    final tap = _tap;
    if (resolve == null || tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de tap/observación de pantalla',
        failureKind: TaskFailureKind.terminal,
      );
    }
    // T2.0: botón de acción SEMÁNTICO (enviar) asociado al input, no un
    // `desc=Enviar` hardcodeado que no es universal.
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

    // T2.7 — el `tap == true` NO es éxito: observar el estado real. El composer
    // debe quedar vacío tras enviar. Si aún conserva el borrador, el envío no
    // se produjo (reintentable). Sin fuente de observación → completedUnverified
    // honesto, nunca completed.
    final observe = _observeInputText;
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
    if (goal.draft.isNotEmpty && remaining.contains(goal.draft)) {
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

  // ── T2.9 — búsqueda genérica dentro de una app ─────────────────────────────

  Future<TaskStepResult> _writeQuery(_GoalContext goal) async {
    if (goal.query.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin query de búsqueda',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolveInput = _resolveInputSurface;
    final write = _writeText;
    if (resolveInput == null || write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura/observación',
        failureKind: TaskFailureKind.terminal,
      );
    }

    var input = await resolveInput();
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

    final ok = await write(input, goal.query);
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

  Future<TaskStepResult> _submitSearch(_GoalContext goal) async {
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
    final ok = await tap(action);
    return ok
        ? const TaskStepResult(
            status: TaskStepStatus.completed,
            reason: 'búsqueda enviada',
          )
        : const TaskStepResult(
            status: TaskStepStatus.failed,
            reason: 'tap de submit devolvió false',
            failureKind: TaskFailureKind.recoverable,
          );
  }

  _GoalContext _parseGoal(String goal) {
    final g = goal.toLowerCase();

    // App: "abre X" / "ve a X" / "ir a X" / "entra a X" o "… en X" (búsqueda).
    final appMatch = RegExp(
      r'(?:abre|abrir|ve a|ir a|entra a|entra en)\s+(\w+)',
    ).firstMatch(g);
    final enAppMatch = RegExp(r'en\s+(\w+)\s*$').firstMatch(g);
    var appName = appMatch?.group(1) ?? '';
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

    // Target/draft (mensajería) vía MessageIntentParser (":" y " que ").
    final intent = const MessageIntentParser().parse(goal);
    return _GoalContext(
      appName: appName,
      target: intent.recipient,
      draft: intent.message,
      query: query,
    );
  }
}

class _GoalContext {
  final String appName;
  final String target;
  final String draft;

  /// T2.9 — query de búsqueda ("abre YouTube y busca X").
  final String query;

  const _GoalContext({
    this.appName = '',
    this.target = '',
    this.draft = '',
    this.query = '',
  });
}
