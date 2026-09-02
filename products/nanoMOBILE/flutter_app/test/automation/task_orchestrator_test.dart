import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/governance/action_confirmation.dart';
import 'package:nanoai/features/automation/engine/orchestration/commit_guard.dart';
import 'package:nanoai/features/automation/engine/orchestration/execution_journal.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_orchestrator.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_plan.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/nano_ui_object.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/semantic_role.dart';

const _completed = TaskActionResult(
  status: TaskActionStatus.completed,
  reason: 'acción verificada',
);
const _completedUnverified = TaskActionResult(
  status: TaskActionStatus.completedUnverified,
  reason: 'acción ejecutada sin evidencia suficiente',
);
const _failed = TaskActionResult(
  status: TaskActionStatus.failed,
  reason: 'acción no disponible',
);

TaskOrchestrator _orchestrator({
  TaskLaunchApp? launchApp,
  TaskTap? tap,
  TaskWriteText? writeText,
  Future<String?> Function(String kind)? resolveInputSurfaceFor,
  Future<String?> Function(String kind)? resolveActionSurface,
  CommitGuard? commitGuard,
  ExecutionJournal? journal,
}) {
  return TaskOrchestrator(
    listNotifications: () async => [],
    openUrl: (_, {confirmedActionSignature}) async => _failed,
    writeFile: (_, __, {confirmedActionSignature}) async => _failed,
    launchApp: launchApp,
    tap: tap,
    writeText: writeText,
    resolveInputSurfaceFor: resolveInputSurfaceFor,
    resolveActionSurface: resolveActionSurface,
    commitGuard: commitGuard,
    journal: journal,
  );
}

NanoUiObject _object({
  required String id,
  required SemanticRole role,
  required String text,
  required NanoBounds bounds,
  required int sourceIndex,
  String description = '',
  String resourceId = '',
  bool editable = false,
  bool clickable = false,
}) {
  return NanoUiObject(
    id: id,
    role: role,
    label: text.isNotEmpty ? text : description,
    text: text,
    description: description,
    bounds: bounds,
    enabled: true,
    visible: true,
    clickable: clickable,
    editable: editable,
    scrollable: false,
    checked: false,
    focusable: editable || clickable,
    focused: editable,
    nativeClass: switch (role) {
      SemanticRole.textField => 'android.widget.EditText',
      SemanticRole.button || SemanticRole.iconButton => 'android.widget.Button',
      _ => 'android.widget.TextView',
    },
    resourceId: resourceId,
    parentId: null,
    confidence: 1,
    evidence: const [SemanticEvidenceSource.accessibilityFlag],
    sourceIndex: sourceIndex,
    packageName: 'com.chat',
    windowId: 7,
    rootIdentity: 'root-7',
  );
}

ScreenGraph _chatGraph({
  required String draft,
  bool includeConversation = true,
  bool includeLocalEcho = false,
  bool truncated = false,
}) {
  final objects = <NanoUiObject>[
    if (includeConversation)
      _object(
        id: 'title',
        role: SemanticRole.text,
        text: 'Juan',
        bounds: const NanoBounds(left: 20, top: 30, right: 300, bottom: 80),
        sourceIndex: 0,
      ),
    _object(
      id: 'composer',
      role: SemanticRole.textField,
      text: draft,
      description: 'Escribe un mensaje',
      resourceId: 'com.chat:id/composer',
      editable: true,
      bounds: const NanoBounds(left: 20, top: 700, right: 850, bottom: 790),
      sourceIndex: 1,
    ),
    _object(
      id: 'send',
      role: SemanticRole.button,
      text: '',
      description: 'Enviar',
      resourceId: 'com.chat:id/send',
      clickable: true,
      bounds: const NanoBounds(left: 870, top: 700, right: 980, bottom: 790),
      sourceIndex: 2,
    ),
    if (includeLocalEcho)
      _object(
        id: 'bubble-new',
        role: SemanticRole.text,
        text: 'hola',
        bounds: const NanoBounds(left: 500, top: 600, right: 950, bottom: 680),
        sourceIndex: 3,
      ),
  ];
  return ScreenGraph(
    package: 'com.chat',
    objects: objects,
    relations: const [],
    truncated: truncated,
  );
}

TaskPlan _sendPlan() => const TaskPlan(
  goal: 'escríbele a Juan: hola',
  steps: [TaskStep(id: 'send', semanticAction: 'sendMessage')],
);

void main() {
  group('TaskOrchestrator · contratos tipados', () {
    test(
      'writeMessage usa una superficie observada y conserva certeza',
      () async {
        String? selector;
        String? text;
        final orchestrator = _orchestrator(
          writeText: (value, valueText, {confirmedActionSignature}) async {
            selector = value;
            text = valueText;
            return _completed;
          },
          resolveInputSurfaceFor: (kind) async =>
              kind == 'message' ? 'id=com.chat:id/composer' : null,
        );

        final result = await orchestrator.run(
          const TaskPlan(
            goal: 'escríbele a Juan: hola',
            steps: [TaskStep(id: 'write', semanticAction: 'writeMessage')],
          ),
        );

        expect(result.single.status, TaskStepStatus.completed);
        expect(selector, 'id=com.chat:id/composer');
        expect(text, 'hola');
      },
    );

    test('no inventa un selector cuando no observa el compositor', () async {
      var writes = 0;
      final orchestrator = _orchestrator(
        writeText: (_, __, {confirmedActionSignature}) async {
          writes++;
          return _completed;
        },
        resolveInputSurfaceFor: (_) async => null,
      );

      final result = await orchestrator.run(
        const TaskPlan(
          goal: 'escríbele a Juan: hola',
          steps: [TaskStep(id: 'write', semanticAction: 'writeMessage')],
        ),
      );

      expect(result.single.status, TaskStepStatus.needsMoreEvidence);
      expect(writes, 0);
    });

    test(
      'una dependencia ejecutada pero no verificada bloquea el envío',
      () async {
        var taps = 0;
        final orchestrator = _orchestrator(
          writeText: (_, __, {confirmedActionSignature}) async =>
              _completedUnverified,
          resolveInputSurfaceFor: (_) async => 'id=com.chat:id/composer',
          tap: (_, {confirmedActionSignature}) async {
            taps++;
            return _completed;
          },
          commitGuard: CommitGuard(
            observe: () async => _chatGraph(draft: 'hola'),
          ),
        );
        const plan = TaskPlan(
          goal: 'escríbele a Juan: hola',
          steps: [
            TaskStep(id: 'write', semanticAction: 'writeMessage'),
            TaskStep(
              id: 'send',
              semanticAction: 'sendMessage',
              dependencies: ['write'],
              dependencyEvidence: {'write': RequiredEvidence.verified},
            ),
          ],
        );

        final result = await orchestrator.run(plan);

        expect(result.map((item) => item.status), [
          TaskStepStatus.completedUnverified,
          TaskStepStatus.needsMoreEvidence,
        ]);
        expect(taps, 0);
      },
    );
  });

  group('TaskOrchestrator · CommitGuard y exactamente una vez', () {
    test('verifica un envío local con un único tap', () async {
      var observations = 0;
      var taps = 0;
      final guard = CommitGuard(
        observe: () async {
          observations++;
          return observations < 3
              ? _chatGraph(draft: 'hola')
              : _chatGraph(draft: '', includeLocalEcho: true);
        },
      );
      final orchestrator = _orchestrator(
        tap: (_, {confirmedActionSignature}) async {
          taps++;
          return _completed;
        },
        commitGuard: guard,
      );

      final result = await orchestrator.run(_sendPlan());

      expect(result.single.status, TaskStepStatus.completed);
      expect(result.single.reason, contains('entrega remota desconocida'));
      expect(taps, 1);
    });

    test('si cambia la conversación antes del commit hace cero taps', () async {
      var observations = 0;
      var taps = 0;
      final guard = CommitGuard(
        observe: () async {
          observations++;
          return observations == 1
              ? _chatGraph(draft: 'hola')
              : _chatGraph(draft: 'hola', includeConversation: false);
        },
      );
      final orchestrator = _orchestrator(
        tap: (_, {confirmedActionSignature}) async {
          taps++;
          return _completed;
        },
        commitGuard: guard,
      );

      final result = await orchestrator.run(_sendPlan());

      expect(result.single.status, TaskStepStatus.needsMoreEvidence);
      expect(taps, 0);
    });

    test(
      'tras despachar no reintenta si el resultado es desconocido',
      () async {
        var taps = 0;
        final guard = CommitGuard(
          observe: () async => _chatGraph(draft: 'hola'),
        );
        final orchestrator = _orchestrator(
          tap: (_, {confirmedActionSignature}) async {
            taps++;
            return _completed;
          },
          commitGuard: guard,
        );

        final result = await orchestrator.run(_sendPlan());

        expect(result.single.status, TaskStepStatus.outcomeUnknown);
        expect(taps, 1);
      },
    );

    test('snapshot truncado bloquea el commit antes del tap', () async {
      var taps = 0;
      final orchestrator = _orchestrator(
        tap: (_, {confirmedActionSignature}) async {
          taps++;
          return _completed;
        },
        commitGuard: CommitGuard(
          observe: () async => _chatGraph(draft: 'hola', truncated: true),
        ),
      );

      final result = await orchestrator.run(_sendPlan());

      expect(result.single.status, TaskStepStatus.needsMoreEvidence);
      expect(taps, 0);
    });

    test(
      'resume confirmado no vuelve a escribir ni reproduce pasos previos',
      () async {
        var writes = 0;
        var physicalTaps = 0;
        final orchestrator = _orchestrator(
          writeText: (_, __, {confirmedActionSignature}) async {
            writes++;
            return _completed;
          },
          resolveInputSurfaceFor: (_) async => 'id=com.chat:id/composer',
          tap: (_, {confirmedActionSignature}) async {
            if (confirmedActionSignature != 'tap-send') {
              return const TaskActionResult(
                status: TaskActionStatus.needsConfirmation,
                reason: 'confirmación requerida',
                actionSignature: 'tap-send',
              );
            }
            physicalTaps++;
            return _completed;
          },
          commitGuard: CommitGuard(
            observe: () async => physicalTaps == 0
                ? _chatGraph(draft: 'hola')
                : _chatGraph(draft: '', includeLocalEcho: true),
          ),
        );
        const plan = TaskPlan(
          goal: 'escríbele a Juan: hola',
          steps: [
            TaskStep(id: 'write', semanticAction: 'writeMessage'),
            TaskStep(
              id: 'send',
              semanticAction: 'sendMessage',
              dependencies: ['write'],
              dependencyEvidence: {'write': RequiredEvidence.verified},
            ),
          ],
        );

        final paused = await orchestrator.run(plan, executionId: 'run-1');
        expect(paused.last.status, TaskStepStatus.needsConfirmation);
        expect(writes, 1);
        expect(physicalTaps, 0);

        final resumed = await orchestrator.run(
          plan,
          executionId: 'run-1',
          confirmation: paused.last.confirmation,
        );
        expect(resumed.single.status, TaskStepStatus.completed);
        expect(writes, 1);
        expect(physicalTaps, 1);
      },
    );

    test('denegación detiene los pasos posteriores', () async {
      var writes = 0;
      final orchestrator = _orchestrator(
        launchApp: (_, {confirmedActionSignature}) async =>
            const TaskActionResult(
              status: TaskActionStatus.denied,
              reason: 'denegado',
            ),
        writeText: (_, __, {confirmedActionSignature}) async {
          writes++;
          return _completed;
        },
        resolveInputSurfaceFor: (_) async => 'id=com.chat:id/composer',
      );
      const plan = TaskPlan(
        goal: 'abre WhatsApp y escríbele a Juan: hola',
        steps: [
          TaskStep(id: 'open', semanticAction: 'openApp'),
          TaskStep(
            id: 'write',
            semanticAction: 'writeMessage',
            dependencies: ['open'],
          ),
        ],
      );

      final result = await orchestrator.run(plan);

      expect(result.single.status, TaskStepStatus.denied);
      expect(writes, 0);
    });
  });

  test('un commit interrumpido impide repetir el mismo objetivo', () async {
    final journal = InMemoryExecutionJournal();
    await journal.save(
      ExecutionJournalEntry(
        runId: 'previous-run',
        planSignature: 'plan',
        goalFingerprint: canonicalFingerprint('escríbele a Juan: hola'),
        currentStep: 0,
        stepId: 'send',
        status: ExecutionJournalStatus.executing,
        irreversible: true,
        actionSignature: 'action',
        verificationState: 'tap iniciado',
        timestamp: DateTime.now().toUtc(),
      ),
    );
    var taps = 0;
    final orchestrator = _orchestrator(
      journal: journal,
      tap: (_, {confirmedActionSignature}) async {
        taps++;
        return _completed;
      },
      commitGuard: CommitGuard(observe: () async => _chatGraph(draft: 'hola')),
    );

    final result = await orchestrator.run(_sendPlan(), executionId: 'new-run');

    expect(result.single.status, TaskStepStatus.outcomeUnknown);
    expect(taps, 0);
  });
}
