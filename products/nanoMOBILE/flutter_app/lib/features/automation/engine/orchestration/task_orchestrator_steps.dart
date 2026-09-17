part of 'task_orchestrator.dart';

extension _TaskOrchestratorSteps on TaskOrchestrator {
  Future<TaskStepResult> _runStep(
    TaskStep step,
    AutomationContext context, {
    required NavigationHistory navigationHistory,
    String? confirmedActionSignature,
    ExecutionJournalEntry? executionIntent,
  }) async {
    final values = context.world.values;
    final goal = context.conversation;
    switch (step.semanticAction) {
      case 'readNotification':
        return _readNotification(context);
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
          context,
          goal,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'openConversation':
        return _openConversation(
          context,
          goal,
          navigationHistory: navigationHistory,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'activateElement':
        return _activateElement(
          context,
          goal,
          executionIntent: executionIntent,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'fillElement':
        return _fillElement(
          context,
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
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
          executionIntent: executionIntent,
        );
      case 'writeQuery':
        return _writeQuery(
          goal,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'submitSearch':
        return _submitSearch(
          goal,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'selectResult':
        return _selectResult(
          goal,
          executionId: context.execution.executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
      // GAP-06: steps Linux en planes multi-paso. Todos usan _linuxRun que
      // delega al dispatcher (linux.list/readFile/writeFile/run). Si _linuxRun
      // no está inyectado → needsMoreEvidence con razón legible.
      case 'linux_list_files':
        return _linuxStep(
          step,
          values,
          tool: 'linux.list',
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'linux_read_file':
        return _linuxStep(
          step,
          values,
          tool: 'linux.readFile',
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'linux_write_file':
        return _linuxStep(
          step,
          values,
          tool: 'linux.writeFile',
          confirmedActionSignature: confirmedActionSignature,
        );
      case 'linux_run_command':
        return _linuxStep(
          step,
          values,
          tool: 'linux.run',
          confirmedActionSignature: confirmedActionSignature,
        );

      default:
        return const TaskStepResult(
          status: TaskStepStatus.needsMoreEvidence,
          reason: 'semántica desconocida',
        );
    }
  }

  TaskStepResult _readNotification(AutomationContext context) {
    final failure = context.world.notificationFailure;
    if (failure != null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: failure,
        failureKind: TaskFailureKind.terminal,
      );
    }
    final notifications = context.world.notifications;
    if (notifications.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin notificaciones activas',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final first = notifications.first;
    final text = first.messageText.isNotEmpty ? first.messageText : first.text;
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
      semanticAction: 'writeFile',
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
      semanticAction: 'openUrl',
    );
    return _stepFromAction(
      action,
      completedReason: 'URL abierta',
      recoverable: true,
    );
  }

  /// GAP-06: ejecuta un step linux.* (list/readFile/writeFile/run) en un plan
  /// multi-paso. Lee `command`/`path` de [inputBindings] (valores producidos
  /// por pasos previos) y delega a [_linuxRun]. Sin _linuxRun inyectado →
  /// needsMoreEvidence.
  Future<TaskStepResult> _linuxStep(
    TaskStep step,
    Map<TaskValueId, TaskValue> values, {
    required String tool,
    String? confirmedActionSignature,
  }) async {
    final linuxRun = _linuxRun;
    if (linuxRun == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'linuxRun no inyectado en este orchestrator',
        failureKind: TaskFailureKind.terminal,
      );
    }
    // Resolver command/path desde los inputBindings del step.
    // Los steps linux usan 'command' (linux.run) o 'path' (list/readFile/writeFile).
    final commandBinding =
        step.inputBindings['command'] ?? step.inputBindings['path'];
    final commandValue = commandBinding == null
        ? null
        : values[commandBinding.source];
    final command = switch (commandValue) {
      TextValue(:final text) => text.trim(),
      FilePathValue(:final path) => path.trim(),
      _ => '',
    };
    if (command.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'step linux sin binding command/path resuelto',
        failureKind: TaskFailureKind.terminal,
      );
    }
    // 'content' para writeFile (si se pasa como binding).
    final contentBinding = step.inputBindings['content'];
    final contentValue = contentBinding == null
        ? null
        : values[contentBinding.source];
    final content = contentValue is TextValue ? contentValue.text : null;
    // Construir args canónicos según el tool.
    final List<String> arguments = content != null ? [content] : const [];
    final action = await linuxRun(
      command,
      arguments,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: tool,
    );
    return _stepFromAction(
      action,
      completedReason: '$tool completado',
      recoverable: tool == 'linux.run',
    );
  }

  // ── A15.4 — pasos UI (delegan al dispatcher/ScreenGraph) ──────────────────

  Future<TaskStepResult> _openApp(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    String? confirmedActionSignature,
  }) async {
    // T2.8: si el objetivo no nombra la app ("escríbele a Juan"), derivarla de
    // la notificación activa cuyo sender/conversación matchea el target. El
    // package sale de la evidencia real, nunca se inventa. Sin app derivable →
    // needsMoreEvidence honesto (el humano/planner aclara en qué app).
    final notificationFailure = context.world.notificationFailure;
    if (goal.appName.isEmpty && notificationFailure != null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: notificationFailure,
        failureKind: TaskFailureKind.terminal,
      );
    }
    final app = _resolveMessagingApp(context, goal);
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
      semanticAction: 'openApp',
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
  String? _resolveMessagingApp(
    AutomationContext context,
    AutomationConversationSnapshot goal,
  ) {
    if (goal.appName.isNotEmpty) return goal.appName;
    if (goal.target.isEmpty) return null;

    for (final n in context.world.notifications) {
      if (n.packageName.isEmpty) continue;
      if (n.matchesRecipient(goal.target)) return n.packageName;
    }
    return null;
  }

  Future<TaskStepResult> _openConversation(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    required NavigationHistory navigationHistory,
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    if (goal.target.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin conversación objetivo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final resolveAppPackage = _resolveAppPackage;
    if (resolveAppPackage == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin catálogo para resolver el paquete de navegación',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final String? appReference;
    final notificationFailure = context.world.notificationFailure;
    if (goal.appName.isEmpty && notificationFailure != null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: notificationFailure,
        failureKind: TaskFailureKind.terminal,
      );
    }
    appReference = _resolveMessagingApp(context, goal);
    if (appReference == null || appReference.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin app grounded para la conversación objetivo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final String? targetPackage;
    try {
      targetPackage = await resolveAppPackage(appReference);
    } on Object catch (error) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'no se pudo resolver el paquete objetivo: $error',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (targetPackage == null || targetPackage.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'app objetivo ausente o ambigua en el catálogo instalado',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final current = context.perception.situation;
    if (!context.perception.isObserved || current == null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            context.perception.reason ??
            'situación actual ausente o sin evidencia estructural',
        failureKind: TaskFailureKind.terminal,
      );
    }

    final navigationGoal = NavigationGoal(
      targetPackage: targetPackage,
      targetSurface: CurrentSurfaceKind.editable,
      targetEntity: goal.target,
    );
    var decision = _navigator.decide(current, navigationGoal, memory: _memory);
    if (decision.status == NavigationDecisionStatus.needsMoreEvidence &&
        decision.permitsPerceptionEscalation) {
      final perceived = await _perceivedNavigationDecision(
        current,
        navigationGoal,
        decision,
      );
      if (perceived != null) decision = perceived;
    }
    final transition = _transitionVerifier.verify(
      history: navigationHistory,
      current: current,
      goal: navigationGoal,
      decision: decision,
    );
    // AUT-MEM-01: una transición VERIFICADA por la reobservación (cambio real
    // o meta alcanzada) se aprende. La memoria solo registra lo confirmado;
    // el no-progreso (unchanged) nunca se aprende.
    final previousEntry = navigationHistory.lastEntry;
    final memory = _memory;
    if (memory != null &&
        previousEntry != null &&
        (transition.status == NavigationTransitionStatus.changed ||
            transition.status == NavigationTransitionStatus.goalReached)) {
      memory.record(
        packageName: current.packageName,
        fromSurface: previousEntry.fromSurface,
        action: previousEntry.actionKind,
        resultingSurface: current.surfaceKind,
      );
    }
    final progress = navigationHistory.assess(
      situation: current,
      goal: navigationGoal,
      decision: decision,
      transitionUnchanged: transition.isUnchanged,
    );
    if (!progress.mayAct) {
      return TaskStepResult(
        status: TaskStepStatus.failed,
        reason: progress.reason,
        failureKind: TaskFailureKind.terminal,
      );
    }
    switch (decision.status) {
      case NavigationDecisionStatus.arrived:
        return TaskStepResult(
          status: TaskStepStatus.completed,
          reason: '${decision.reason}; ${transition.reason}',
        );
      case NavigationDecisionStatus.needsMoreEvidence:
        return TaskStepResult(
          status: TaskStepStatus.needsMoreEvidence,
          reason: '${decision.reason}; ${transition.reason}',
          failureKind: TaskFailureKind.terminal,
        );
      case NavigationDecisionStatus.act:
        return _executeNavigationDecision(
          decision,
          current: current,
          goal: navigationGoal,
          navigationHistory: navigationHistory,
          executionId: executionId,
          confirmedActionSignature: confirmedActionSignature,
        );
    }
  }

  /// Escalado visual acotado para navegación. Solo entra cuando el navegador
  /// estructural no pudo decidir. Accessibility → OCR → Vision pueden aportar
  /// evidencia, pero el resultado únicamente se convierte en acción si puede
  /// ligarse de nuevo a UN control accesible clicable de la situación actual.
  /// Nunca se toca una coordenada inferida ni se cambia el objetivo.
  Future<NavigationDecision?> _perceivedNavigationDecision(
    CurrentSituation current,
    NavigationGoal goal,
    NavigationDecision fallback,
  ) async {
    final perceive = _targetPerception;
    if (perceive == null || current.packageName != goal.targetPackage) {
      return null;
    }

    final concepts = _perceptionConcepts(current, goal);
    for (final concept in concepts) {
      final result = await perceive(concept, goal.targetPackage);
      if (result is! PerceptionResolved || result.confidence < 0.72) continue;
      final grounded = _groundPerceivedObject(
        current.structuralEvidence,
        result.object,
      );
      if (grounded == null ||
          grounded.editable ||
          grounded.isEditableRole ||
          _selectedInChain(current.structuralEvidence, grounded)) {
        continue;
      }
      final selector = _selectorForPerceivedObject(
        current.structuralEvidence,
        grounded,
      );
      if (selector == null) continue;
      final source = result.evidence.isEmpty
          ? 'percepción'
          : result.evidence.last.source.name;
      return NavigationDecision.act(
        diff: fallback.diff,
        action: NavigationAction.tap(selector),
        reason: 'destino "$concept" observado por $source y revalidado',
      );
    }
    return null;
  }

  /// El escalado caro no prueba una lista universal de palabras. Primero usa
  /// destinos que ya tienen alguna evidencia visible en el snapshot y luego
  /// el objetivo. Queda limitado a tres observaciones por decisión fallida.
  List<String> _perceptionConcepts(
    CurrentSituation current,
    NavigationGoal goal,
  ) {
    const conversationTerms = {
      'chats',
      'mensajes',
      'conversaciones',
      'messages',
      'conversations',
    };
    const searchTerms = {'buscar', 'busca', 'search', 'find'};
    String? conversationConcept;
    String? searchConcept;

    for (final object in current.structuralEvidence.objects) {
      if (!object.visible) continue;
      for (final raw in [object.description, object.text, object.label]) {
        final value = raw.trim();
        if (value.isEmpty) continue;
        final normalized = value.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        final firstSegment = normalized.split(RegExp(r'[,;|•·]')).first.trim();
        if (conversationConcept == null &&
            (conversationTerms.contains(normalized) ||
                conversationTerms.contains(firstSegment))) {
          conversationConcept = value;
        }
        if (searchConcept == null &&
            (searchTerms.contains(normalized) ||
                searchTerms.contains(firstSegment))) {
          searchConcept = value;
        }
      }
    }

    final concepts = <String>{
      if (conversationConcept != null) conversationConcept,
      if (goal.targetEntity case final entity?) entity,
      if (searchConcept != null) searchConcept,
    };
    return List.unmodifiable(concepts.take(3));
  }

  NanoUiObject? _groundPerceivedObject(
    ScreenGraph graph,
    NanoUiObject perceived,
  ) {
    NanoUiObject? observed;
    if (perceived.sourceIndex >= 0) {
      for (final object in graph.objects) {
        if (object.sourceIndex == perceived.sourceIndex &&
            object.windowId == perceived.windowId &&
            object.bounds.left == perceived.bounds.left &&
            object.bounds.top == perceived.bounds.top &&
            object.bounds.right == perceived.bounds.right &&
            object.bounds.bottom == perceived.bounds.bottom) {
          observed = object;
          break;
        }
      }
    } else {
      // OCR/Vision produce un objeto virtual. Se usa solo para encontrar la
      // región correspondiente en el ScreenGraph, nunca como target directo.
      final x = perceived.bounds.centerX;
      final y = perceived.bounds.centerY;
      final spatial =
          graph.objects
              .where((object) {
                final bounds = object.bounds;
                return object.visible &&
                    object.enabled &&
                    bounds.left <= x &&
                    x <= bounds.right &&
                    bounds.top <= y &&
                    y <= bounds.bottom;
              })
              .toList(growable: false)
            ..sort((a, b) {
              final aArea = a.bounds.width * a.bounds.height;
              final bArea = b.bounds.width * b.bounds.height;
              return aArea.compareTo(bArea);
            });
      final byTapTarget = <String, NanoUiObject>{};
      for (final anchor in spatial) {
        final target = _clickableTarget(graph, anchor);
        if (target != null) byTapTarget.putIfAbsent(target.id, () => anchor);
      }
      if (byTapTarget.length == 1) observed = byTapTarget.values.single;
    }
    if (observed == null) return null;
    return _clickableTarget(graph, observed) == null ? null : observed;
  }

  NanoUiObject? _clickableTarget(ScreenGraph graph, NanoUiObject anchor) {
    var current = anchor;
    for (var depth = 0; depth < 6; depth++) {
      if (current.visible && current.enabled && current.clickable) {
        return current;
      }
      final parent = graph.parentOf(current.id);
      if (parent == null) return null;
      current = parent;
    }
    return null;
  }

  String? _selectorForPerceivedObject(ScreenGraph graph, NanoUiObject anchor) {
    final target = _clickableTarget(graph, anchor);
    if (target == null) return null;
    (String, String)? semantic;
    for (final identity in <(String, String)>[
      ('desc', anchor.description),
      ('text', anchor.text),
      ('desc', target.description),
      ('text', target.text),
    ]) {
      final value = identity.$2.trim();
      if (value.isEmpty || value.contains(';')) continue;
      semantic = identity;
      break;
    }

    final resource = anchor.resourceId.isNotEmpty
        ? anchor.resourceId
        : target.resourceId;
    final resourceUnique =
        resource.isNotEmpty &&
        !resource.contains(';') &&
        graph.objects
                .where(
                  (object) =>
                      object.visible &&
                      object.enabled &&
                      object.resourceId == resource,
                )
                .length ==
            1;
    if (semantic == null && !resourceUnique) return null;

    return <String>[
      if (target.packageName.isNotEmpty) 'pkg=${target.packageName}',
      // Un id compartido puede conservarse como ancla secundaria solo cuando
      // el texto/desc exacto lo desambigua. Sin evidencia semántica se exige
      // que el id sea único en el snapshot.
      if (resource.isNotEmpty && !resource.contains(';')) 'id=$resource',
      if (semantic != null) '${semantic.$1}=${semantic.$2.trim()}',
      'editable=false',
    ].join(';');
  }

  bool _selectedInChain(ScreenGraph graph, NanoUiObject anchor) {
    var current = anchor;
    for (var depth = 0; depth < 6; depth++) {
      if (current.selected || current.checked) return true;
      final parent = graph.parentOf(current.id);
      if (parent == null) return false;
      current = parent;
    }
    return false;
  }

  Future<TaskStepResult> _executeNavigationDecision(
    NavigationDecision decision, {
    required CurrentSituation current,
    required NavigationGoal goal,
    required NavigationHistory navigationHistory,
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    final action = decision.action!;
    final TaskActionResult result;
    switch (action.kind) {
      case NavigationActionKind.launchPackage:
        final launch = _launchApp;
        if (launch == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente para abrir el paquete decidido',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await launch(
          action.packageName!,
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
        );
      case NavigationActionKind.tap:
        final tap = _tap;
        if (tap == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de tap para la decisión de navegación',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await tap(
          action.selector!,
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
          executionId: executionId,
        );
      case NavigationActionKind.write:
        final write = _writeText;
        if (write == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de escritura para la decisión de navegación',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await write(
          action.selector!,
          action.text!,
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
        );
      case NavigationActionKind.back:
        final back = _back;
        if (back == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de back para la decisión de navegación',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await back(
          confirmedActionSignature: confirmedActionSignature,
          semanticAction: 'openConversation',
        );
      case NavigationActionKind.scroll:
        final swipe = _swipe;
        if (swipe == null) {
          return const TaskStepResult(
            status: TaskStepStatus.needsMoreEvidence,
            reason: 'sin fuente de desplazamiento para la decisión',
            failureKind: TaskFailureKind.terminal,
          );
        }
        result = await swipe(
          action.scrollDirection == ScrollDirection.up ? 'up' : 'down',
        );
    }

    // El presupuesto de navegación solo cuenta acciones que realmente fueron
    // aceptadas por el adaptador. Un selector ambiguo/notFound devuelve
    // `failed`: registrarlo como gesto intentado falseaba el stuck detector y
    // detenía la recuperación aunque ningún tap hubiera salido al dispositivo.
    if (result.status == TaskActionStatus.completed ||
        result.status == TaskActionStatus.completedUnverified ||
        result.status == TaskActionStatus.outcomeUnknown) {
      navigationHistory.recordAttempted(
        situation: current,
        goal: goal,
        decision: decision,
      );
    }

    if (result.status == TaskActionStatus.completed) {
      return TaskStepResult(
        status: TaskStepStatus.failed,
        reason:
            '${decision.reason}; acción ejecutada, requiere nueva observación',
        failureKind: TaskFailureKind.recoverable,
      );
    }
    if (result.status == TaskActionStatus.completedUnverified) {
      return TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason:
            '${decision.reason}; la acción fue despachada sin transición verificable',
        failureKind: TaskFailureKind.terminal,
      );
    }
    return _stepFromAction(
      result,
      completedReason: 'decisión de navegación ejecutada',
      recoverable: true,
    );
  }
}
