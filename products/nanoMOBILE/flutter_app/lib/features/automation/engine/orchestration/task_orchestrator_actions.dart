part of 'task_orchestrator.dart';

extension _TaskOrchestratorActions on TaskOrchestrator {
  Future<TaskStepResult> _writeMessage(
    AutomationConversationSnapshot goal, {
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
      semanticAction: 'writeMessage',
    );
    return _stepFromAction(
      action,
      completedReason: 'mensaje escrito en superficie editable',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _activateElement(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    String? confirmedActionSignature,
    ExecutionJournalEntry? executionIntent,
  }) async {
    final actionTarget = goal.uiActionTarget.isNotEmpty
        ? goal.uiActionTarget
        : goal.uiTarget;
    if (actionTarget.isEmpty) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin elemento UI objetivo en la orden',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final situation = context.perception.situation;
    if (!context.perception.isObserved || situation == null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            context.perception.reason ??
            'sin situación estructural para resolver el elemento',
        failureKind: TaskFailureKind.terminal,
      );
    }
    var candidates = const EntityActionSurfaceResolver().resolve(
      situation.structuralEvidence,
      actionTarget,
    );
    String? perceptionSource;
    if (candidates.isEmpty) {
      final perceived = await _perceivedActionSurface(situation, actionTarget);
      if (perceived != null) {
        candidates = [perceived.$1];
        perceptionSource = perceived.$2;
      }
    }
    final tap = _tap;
    if (tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de interacción UI',
        failureKind: TaskFailureKind.terminal,
      );
    }

    // Un target de menú no existe en el árbol hasta abrir el overflow. Se
    // permite revelar UNA única superficie transitoria observada, se vuelve a
    // capturar el estado y recién entonces se resuelve el target final. El tap
    // de reveal usa política de navegación; nunca consume ni sustituye la
    // confirmación requerida por activateElement.
    if (candidates.isEmpty) {
      final overflow = const ActionSurfaceResolver().resolve(
        situation.structuralEvidence,
        kind: 'overflow',
      );
      final observe = _currentSituationSource;
      if (overflow != null && observe != null) {
        final revealed = await tap(
          overflow.selector,
          semanticAction: 'revealElement',
          executionId: context.execution.executionId,
        );
        if (!revealed.completed) {
          return _stepFromAction(
            revealed,
            completedReason: 'menú transitorio revelado',
            recoverable: false,
          );
        }
        final refreshed = await observe();
        if (refreshed != null &&
            refreshed.packageName == situation.packageName &&
            refreshed.hasStructuralEvidence) {
          candidates = const EntityActionSurfaceResolver().resolve(
            refreshed.structuralEvidence,
            actionTarget,
          );
          if (candidates.isEmpty) {
            final perceived = await _perceivedActionSurface(
              refreshed,
              actionTarget,
            );
            if (perceived != null) {
              candidates = [perceived.$1];
              perceptionSource = perceived.$2;
            }
          }
        }
      }
    }
    if (candidates.isEmpty) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'elemento "$actionTarget" no visible o no accionable',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (candidates.length != 1) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            'elemento "$actionTarget" ambiguo: '
            '${candidates.length} destinos accionables',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await tap(
      candidates.single.selector,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'activateElement',
      executionId: context.execution.executionId,
      executionIntent: executionIntent,
    );
    return _stepFromAction(
      action,
      completedReason:
          'elemento "$actionTarget" activado con transición verificada'
          '${perceptionSource == null ? '' : ' ($perceptionSource)'}',
      recoverable: false,
    );
  }

  /// Escalado visual para una acción genérica. Comparte exactamente la misma
  /// regla de seguridad de navegación: OCR/Vision solo aportan evidencia; el
  /// target final debe existir como un único control accesible clicable en el
  /// ScreenGraph capturado por el owner de la decisión.
  Future<(ResolvedSurface, String)?> _perceivedActionSurface(
    CurrentSituation situation,
    String concept,
  ) async {
    final perceive = _targetPerception;
    if (perceive == null || situation.packageName.isEmpty) return null;
    final result = await perceive(concept, situation.packageName);
    if (result is! PerceptionResolved || result.confidence < 0.72) return null;
    final grounded = _groundPerceivedObject(
      situation.structuralEvidence,
      result.object,
    );
    if (grounded == null ||
        grounded.editable ||
        grounded.isEditableRole ||
        _selectedInChain(situation.structuralEvidence, grounded)) {
      return null;
    }
    final selector = _selectorForPerceivedObject(
      situation.structuralEvidence,
      grounded,
    );
    if (selector == null) return null;
    final source = result.evidence.isEmpty
        ? 'percepción revalidada'
        : '${result.evidence.last.source.name} revalidado';
    return (
      ResolvedSurface(grounded, selector, 'target visual grounded'),
      source,
    );
  }

  Future<TaskStepResult> _fillElement(
    AutomationContext context,
    AutomationConversationSnapshot goal, {
    String? confirmedActionSignature,
  }) async {
    final mayUseSoleEditable =
        goal.uiTarget.isEmpty && goal.uiActionTarget.isNotEmpty;
    if (goal.uiText.isEmpty || (goal.uiTarget.isEmpty && !mayUseSoleEditable)) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin campo UI o texto objetivo en la orden',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final situation = context.perception.situation;
    if (!context.perception.isObserved || situation == null) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            context.perception.reason ??
            'sin situación estructural para resolver el campo',
        failureKind: TaskFailureKind.terminal,
      );
    }
    const inputResolver = EntityInputSurfaceResolver();
    final candidates = mayUseSoleEditable
        ? inputResolver.resolveSoleEditable(
            situation.structuralEvidence,
            packageName: situation.packageName,
          )
        : inputResolver.resolve(
            situation.structuralEvidence,
            goal.uiTarget,
            packageName: situation.packageName,
          );
    final fieldLabel = mayUseSoleEditable
        ? 'único campo editable'
        : 'campo "${goal.uiTarget}"';
    if (candidates.isEmpty) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: '$fieldLabel no visible o sin selector estable',
        failureKind: TaskFailureKind.terminal,
      );
    }
    if (candidates.length != 1) {
      return TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason:
            '$fieldLabel ambiguo: '
            '${candidates.length} editables coinciden',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final write = _writeText;
    if (write == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'sin fuente de escritura UI',
        failureKind: TaskFailureKind.terminal,
      );
    }
    final action = await write(
      candidates.single.selector,
      goal.uiText,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'fillElement',
    );
    return _stepFromAction(
      action,
      completedReason: '$fieldLabel escrito y verificado exactamente',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _sendMessage(
    AutomationConversationSnapshot goal, {
    required String executionId,
    String? confirmedActionSignature,
    ExecutionJournalEntry? executionIntent,
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
      semanticAction: 'sendMessage',
      executionId: executionId,
      executionIntent: executionIntent,
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
      SendEvidenceStatus.incompleteEvidence ||
      SendEvidenceStatus.notExecuted => TaskStepResult(
        status: TaskStepStatus.outcomeUnknown,
        reason: evidence.reason,
        failureKind: TaskFailureKind.terminal,
      ),
    };
  }

  // ── T2.9 — búsqueda genérica dentro de una app ─────────────────────────────

  Future<TaskStepResult> _writeQuery(
    AutomationConversationSnapshot goal, {
    required String executionId,
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
        // Recuperación: una superficie interna sin búsqueda visible (player,
        // detalle). Primero el botón atrás de la UI (vuelve a la raíz de la
        // MISMA app); solo si no existe, el back del sistema — y únicamente
        // cuando la app activa es la esperada (el back del sistema puede
        // salir de la app). El retry reintenta con la búsqueda disponible;
        // acotado por el presupuesto de reintentos.
        final uiBack = await resolveAction('back');
        if (uiBack != null && uiBack.isNotEmpty) {
          final backed = await tap(uiBack, semanticAction: 'writeQuery');
          if (backed.status == TaskActionStatus.completed) {
            return const TaskStepResult(
              status: TaskStepStatus.failed,
              reason:
                  'superficie interna sin búsqueda; botón atrás ejecutado, reintentar',
              failureKind: TaskFailureKind.recoverable,
            );
          }
        }
        final expectedPackage = goal.appName.isEmpty
            ? ''
            : await _resolveAppPackage?.call(goal.appName) ?? '';
        final situation = _currentSituationSource == null
            ? null
            : await _currentSituationSource();
        final activePackage = situation?.packageName ?? '';
        final back = _back;
        if (back != null &&
            expectedPackage.isNotEmpty &&
            activePackage == expectedPackage) {
          final backed = await back(semanticAction: 'writeQuery');
          if (backed.status == TaskActionStatus.completed) {
            return const TaskStepResult(
              status: TaskStepStatus.failed,
              reason:
                  'superficie interna sin búsqueda; atrás ejecutado, reintentar',
              failureKind: TaskFailureKind.recoverable,
            );
          }
        }
        return const TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'sin superficie de búsqueda',
          failureKind: TaskFailureKind.recoverable,
        );
      }
      final openSearch = await tap(
        icon,
        confirmedActionSignature: confirmedActionSignature,
        semanticAction: 'writeQuery',
        executionId: executionId,
      );
      if (!openSearch.completed) {
        return _stepFromAction(
          openSearch,
          completedReason: 'búsqueda abierta',
          recoverable: true,
        );
      }
      // La pantalla de búsqueda aparece con una transición: reobservar con
      // esperas cortas hasta que el campo editable sea observable. Sin
      // espera, el snapshot captura la pantalla previa y el campo "no
      // existe" aunque ya esté apareciendo.
      input = await _resolveInputWithSettle(resolveInput);
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
      semanticAction: 'writeQuery',
    );
    return _stepFromAction(
      action,
      completedReason: 'query escrita en el campo de búsqueda',
      recoverable: true,
    );
  }

  Future<TaskStepResult> _submitSearch(
    AutomationConversationSnapshot goal, {
    required String executionId,
    String? confirmedActionSignature,
  }) async {
    // Captura PRE una sola vez. Tanto el botón visible como ACTION_IME_ENTER
    // deben demostrar después una transición observable; aceptar la acción del
    // sistema no equivale por sí mismo a completar la búsqueda.
    final readText = _readVisibleText;
    final detect = _detectSearchResults;
    final before = readText != null ? await readText() : null;
    final beforeResults = detect != null ? await detect() : null;
    final resolveAction = _resolveActionSurface;
    final tap = _tap;
    final action = resolveAction == null ? null : await resolveAction('search');
    if (action == null || action.isEmpty) {
      // Navegadores y muchas superficies no exponen un botón de submit en el
      // árbol de la app: la acción real vive en el editor/IME. Se ejecuta sólo
      // sobre el único campo editable enfocado y, si se expresó una app, el
      // nativo exige que el package siga coincidiendo.
      final submitInput = _submitInput;
      if (submitInput == null) {
        return const TaskStepResult(
          status: TaskStepStatus.completedUnverified,
          reason: 'query escrita; sin botón ni adaptador IME para submit',
        );
      }
      final expectedPackage = goal.appName.isEmpty
          ? ''
          : await _resolveAppPackage?.call(goal.appName) ?? '';
      final submitted = await submitInput(expectedPackageName: expectedPackage);
      if (!submitted.completed) {
        return _stepFromAction(
          submitted,
          completedReason: 'búsqueda enviada mediante el editor',
          recoverable: true,
        );
      }
      return _verifySearchSubmission(
        beforeText: before,
        beforeResults: beforeResults,
        acceptedReason: submitted.reason,
      );
    }
    if (tap == null) {
      return const TaskStepResult(
        status: TaskStepStatus.needsMoreEvidence,
        reason: 'botón de búsqueda observado, pero no hay ejecutor de toque',
        failureKind: TaskFailureKind.terminal,
      );
    }

    final submitted = await tap(
      action,
      confirmedActionSignature: confirmedActionSignature,
      semanticAction: 'submitSearch',
      executionId: executionId,
    );
    if (!submitted.completed) {
      return _stepFromAction(
        submitted,
        completedReason: 'búsqueda enviada',
        recoverable: true,
      );
    }

    return _verifySearchSubmission(
      beforeText: before,
      beforeResults: beforeResults,
      acceptedReason: 'botón de búsqueda aceptado',
    );
  }

  /// Verificación POST acotada y solo observacional. Las aplicaciones actualizan
  /// su árbol de accesibilidad de forma asíncrona; por eso se reobserva con un
  /// presupuesto corto. Nunca repite el submit ni transforma ausencia de
  /// evidencia en éxito.
  Future<TaskStepResult> _verifySearchSubmission({
    required String? beforeText,
    required int? beforeResults,
    required String acceptedReason,
  }) async {
    final readText = _readVisibleText;
    final detect = _detectSearchResults;
    if (readText == null && detect == null) {
      return TaskStepResult(
        status: TaskStepStatus.completedUnverified,
        reason: '$acceptedReason; sin fuente de verificación posterior',
      );
    }

    const waits = <Duration>[
      Duration.zero,
      Duration(milliseconds: 120),
      Duration(milliseconds: 240),
      Duration(milliseconds: 480),
    ];
    var partialEvidence = false;
    for (final wait in waits) {
      if (wait != Duration.zero) await Future<void>.delayed(wait);
      final afterText = readText != null ? await readText() : null;
      final afterResults = detect != null ? await detect() : null;
      final changed =
          beforeText != null && afterText != null && beforeText != afterText;
      final hasResults = afterResults != null && afterResults > 0;
      final resultSetChanged =
          beforeResults != null &&
          afterResults != null &&
          beforeResults != afterResults;

      if (changed && (hasResults || resultSetChanged)) {
        return TaskStepResult(
          status: TaskStepStatus.completed,
          reason:
              'búsqueda verificada: cambió la superficie y se observaron '
              '$afterResults resultado(s)',
        );
      }
      partialEvidence = partialEvidence || changed || resultSetChanged;
    }

    return TaskStepResult(
      status: TaskStepStatus.completedUnverified,
      reason: partialEvidence
          ? '$acceptedReason; transición observada sin resultados suficientes'
          : '$acceptedReason; sin cambio detectable dentro del presupuesto',
    );
  }

  // ── T2.9-select — selección semántica de resultado observado ───────────────

  Future<TaskStepResult> _selectResult(
    AutomationConversationSnapshot goal, {
    required String executionId,
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
      // Reproducción automática ("reproduce X"): el primer resultado es el
      // destino por defecto; la unicidad se re-verifica en el snapshot.
      target = const ResultOrdinal(1);
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
      semanticAction: 'selectResult',
      executionId: executionId,
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
      // YouTube (y reproductores similares): el anuncio aparece tras unos
      // segundos de reproducción. Un intento único de salto — si no hay
      // botón observable, el video continúa sin intervención.
      await _skipAdIfPresent();
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

  /// Reobserva el campo de búsqueda con esperas cortas: las pantallas de
  /// búsqueda entran con transición y el snapshot inmediato captura la
  /// pantalla anterior. Presupuesto acotado (~2s total).
}
