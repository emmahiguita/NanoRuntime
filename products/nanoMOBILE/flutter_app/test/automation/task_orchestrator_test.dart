import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_orchestrator.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_plan.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/perception/search_result_resolver.dart';

void main() {
  group('TaskOrchestrator · write/send con superficie grounded (T2.0)', () {
    test(
      'writeMessage usa resolveInputSurface (no selector vacío)',
      () async {
        String? writtenSelector;
        final o = TaskOrchestrator(
          listNotifications: () async => [],
          openUrl: (_) async => false,
          writeFile: (_, __) async => false,
          writeText: (selector, text) async {
            writtenSelector = selector;
            return true;
          },
          resolveInputSurface: () async => 'id=com.t:id/composer',
        );
        final plan = TaskPlan(goal: 'escribe a Juan: hola', steps: const [
          TaskStep(id: 'w', semanticAction: 'writeMessage'),
        ]);
        final results = await o.run(plan);
        expect(results.first.status, TaskStepStatus.completed);
        expect(writtenSelector, 'id=com.t:id/composer');
      },
    );

    test(
      'sendMessage usa resolveActionSurface (no desc=Enviar hardcodeado)',
      () async {
        String? tappedSelector;
        final o = TaskOrchestrator(
          listNotifications: () async => [],
          openUrl: (_) async => false,
          writeFile: (_, __) async => false,
          tap: (selector) async {
            tappedSelector = selector;
            return true;
          },
          resolveActionSurface: (_) async => 'id=com.t:id/send',
          observeInputText: () async => '',
        );
        final plan = TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
          TaskStep(id: 's', semanticAction: 'sendMessage'),
        ]);
        final results = await o.run(plan);
        expect(results.first.status, TaskStepStatus.completed);
        expect(tappedSelector, 'id=com.t:id/send');
      },
    );

    test('sin superficie de entrada → needsMoreEvidence (no inventa)', () async {
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        writeText: (_, __) async => true,
        resolveInputSurface: () async => null,
      );
      final plan = TaskPlan(goal: 'escribe a Juan: hola', steps: const [
        TaskStep(id: 'w', semanticAction: 'writeMessage'),
      ]);
      final results = await o.run(plan);
      expect(results.first.status, TaskStepStatus.needsMoreEvidence);
    });
  });

  group('TaskOrchestrator · T2.7 verificación de envío', () {
    TaskOrchestrator sender({
      Future<String?> Function()? observeInputText,
      Future<bool> Function(String)? tap,
    }) => TaskOrchestrator(
      listNotifications: () async => [],
      openUrl: (_) async => false,
      writeFile: (_, __) async => false,
      tap: tap ?? (_) async => true,
      resolveActionSurface: (_) async => 'id=com.t:id/send',
      observeInputText: observeInputText,
    );

    test('composer vaciado → completed', () async {
      final o = sender(observeInputText: () async => '');
      final r = await o.run(
        TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
          TaskStep(id: 's', semanticAction: 'sendMessage'),
        ]),
      );
      expect(r.first.status, TaskStepStatus.completed);
    });

    test('composer aún contiene el borrador → failed (reintentable)', () async {
      final o = sender(observeInputText: () async => 'hola');
      final r = await o.run(
        TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
          TaskStep(id: 's', semanticAction: 'sendMessage'),
        ]),
      );
      expect(r.first.status, TaskStepStatus.failed);
      expect(r.first.failureKind, TaskFailureKind.recoverable);
    });

    test('sin fuente de observación → completedUnverified (no inventa éxito)', () async {
      final o = sender(observeInputText: null);
      final r = await o.run(
        TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
          TaskStep(id: 's', semanticAction: 'sendMessage'),
        ]),
      );
      expect(r.first.status, TaskStepStatus.completedUnverified);
    });
  });

  group('TaskOrchestrator · T2.8 app de mensajería derivada de notificación', () {
    test(
      'sin app nombrada, deriva el package de la notificación que matchea',
      () async {
        String? launched;
        final o = TaskOrchestrator(
          listNotifications: () async => [
            {'package': 'com.whatsapp', 'sender': 'Juan', 'title': 'WhatsApp'},
          ],
          openUrl: (_) async => false,
          writeFile: (_, __) async => false,
          launchApp: (app) async {
            launched = app;
            return true;
          },
        );
        final plan = TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
          TaskStep(id: 'open_app', semanticAction: 'openApp'),
        ]);
        final results = await o.run(plan);
        expect(results.first.status, TaskStepStatus.completed);
        expect(launched, 'com.whatsapp');
      },
    );

    test('app nombrada explícita gana sobre la derivada', () async {
      String? launched;
      final o = TaskOrchestrator(
        listNotifications: () async => [
          {'package': 'com.whatsapp', 'sender': 'Juan', 'title': 'WhatsApp'},
        ],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        launchApp: (app) async {
          launched = app;
          return true;
        },
      );
      final plan = TaskPlan(
        goal: 'abre Telegram y escríbele a Juan: hola',
        steps: const [TaskStep(id: 'open_app', semanticAction: 'openApp')],
      );
      final results = await o.run(plan);
      expect(results.first.status, TaskStepStatus.completed);
      expect(launched, 'telegram');
    });

    test('sin app ni notificación que matchee → needsMoreEvidence', () async {
      final o = TaskOrchestrator(
        listNotifications: () async => [
          {'package': 'com.whatsapp', 'sender': 'María', 'title': 'WhatsApp'},
        ],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        launchApp: (_) async => true,
      );
      final plan = TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
        TaskStep(id: 'open_app', semanticAction: 'openApp'),
      ]);
      final results = await o.run(plan);
      expect(results.first.status, TaskStepStatus.needsMoreEvidence);
    });
  });

  group('TaskOrchestrator · T2.9 búsqueda de conversación', () {
    test('conversación no visible → la localiza vía búsqueda', () async {
      final tapLog = <String>[];
      final writeLog = <String>[];
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (sel) async {
          tapLog.add(sel);
          // La ruta directa falla; solo el tap del RESULTADO tiene éxito.
          return sel == 'text=Juan;editable=false';
        },
        writeText: (sel, text) async {
          writeLog.add('$sel:$text');
          return true;
        },
        resolveInputSurface: () async => 'id=search_field',
        resolveActionSurface: (kind) async =>
            kind == 'search' ? 'id=search_icon' : null,
      );
      final plan = TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
        TaskStep(id: 'open_conv', semanticAction: 'openConversation'),
      ]);
      final results = await o.run(plan);
      expect(results.first.status, TaskStepStatus.completed);
      expect(results.first.reason, 'conversación abierta vía búsqueda');
      expect(tapLog, ['text=Juan', 'id=search_icon', 'text=Juan;editable=false']);
      expect(writeLog, ['id=search_field:Juan']);
    });

    test('sin fuentes de búsqueda → failed recoverable (no inventa)', () async {
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (_) async => false,
        // Sin resolvers de búsqueda (null) → fallo honesto.
      );
      final plan = TaskPlan(goal: 'escríbele a Juan: hola', steps: const [
        TaskStep(id: 'open_conv', semanticAction: 'openConversation'),
      ]);
      final results = await o.run(plan);
      expect(results.first.status, TaskStepStatus.failed);
      expect(results.first.failureKind, TaskFailureKind.recoverable);
    });
  });

  group('TaskOrchestrator · flujo de mensajería completo (E2E con fakes)', () {
    test(
      'openApp → openConversation → writeMessage → sendMessage, todo verified',
      () async {
        final tapLog = <String>[];
        final writeLog = <String>[];
        final launchLog = <String>[];
        final o = TaskOrchestrator(
          listNotifications: () async => [
            {'package': 'com.whatsapp', 'sender': 'Juan', 'title': 'WhatsApp'},
          ],
          openUrl: (_) async => false,
          writeFile: (_, __) async => false,
          launchApp: (app) async {
            launchLog.add(app);
            return true;
          },
          tap: (sel) async {
            tapLog.add(sel);
            return true;
          },
          writeText: (sel, text) async {
            writeLog.add('$sel:$text');
            return true;
          },
          resolveInputSurface: () async => 'id=composer',
          resolveActionSurface: (kind) async =>
              kind == 'send' ? 'id=send' : null,
          observeInputText: () async => '',
        );
        final plan = const TaskPlanner().plan('escríbele a Juan: hola');
        expect(plan, isNotNull);
        final results = await o.run(plan!);
        expect(
          results.map((r) => r.status),
          everyElement(TaskStepStatus.completed),
        );
        expect(launchLog, ['com.whatsapp']);
        expect(tapLog, ['text=Juan', 'id=send']);
        expect(writeLog, ['id=composer:hola']);
      },
    );
  });

  group('TaskOrchestrator · T2.9 búsqueda genérica', () {
    test(
      '"abre YouTube y busca NanoRuntime" → openApp → writeQuery → submitSearch',
      () async {
        final tapLog = <String>[];
        final writeLog = <String>[];
        final launchLog = <String>[];
        final o = TaskOrchestrator(
          listNotifications: () async => [],
          openUrl: (_) async => false,
          writeFile: (_, __) async => false,
          launchApp: (app) async {
            launchLog.add(app);
            return true;
          },
          tap: (sel) async {
            tapLog.add(sel);
            return true;
          },
          writeText: (sel, text) async {
            writeLog.add('$sel:$text');
            return true;
          },
          resolveInputSurface: () async => 'id=search_field',
          resolveActionSurface: (kind) async =>
              kind == 'search' ? 'id=search_icon' : null,
        );
        final plan = const TaskPlanner().plan(
          'abre YouTube y busca NanoRuntime',
        );
        expect(plan, isNotNull);
        final results = await o.run(plan!);
        expect(
          results.map((r) => r.status),
          everyElement(TaskStepStatus.completed),
        );
        expect(launchLog, ['youtube']);
        // El query conserva el case original (NanoRuntime, no nanoruntime).
        expect(writeLog, ['id=search_field:NanoRuntime']);
        expect(tapLog, ['id=search_icon']); // submit
      },
    );

    test(
      '"busca NanoRuntime en YouTube" → app desde "en X" + query con case',
      () async {
        final launchLog = <String>[];
        final writeLog = <String>[];
        final o = TaskOrchestrator(
          listNotifications: () async => [],
          openUrl: (_) async => false,
          writeFile: (_, __) async => false,
          launchApp: (app) async {
            launchLog.add(app);
            return true;
          },
          tap: (_) async => true,
          writeText: (sel, text) async {
            writeLog.add('$sel:$text');
            return true;
          },
          resolveInputSurface: () async => 'id=search_field',
          resolveActionSurface: (kind) async =>
              kind == 'search' ? 'id=search_icon' : null,
        );
        final plan = const TaskPlanner().plan('busca NanoRuntime en YouTube');
        expect(plan, isNotNull);
        await o.run(plan!);
        expect(launchLog, ['youtube']);
        expect(writeLog, ['id=search_field:NanoRuntime']);
      },
    );

    test('writeQuery abre la búsqueda tocando el icono si no hay campo', () async {
      final tapLog = <String>[];
      var inputCalls = 0;
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (sel) async {
          tapLog.add(sel);
          return true;
        },
        writeText: (_, __) async => true,
        resolveInputSurface: () async {
          inputCalls++;
          // 1ª llamada: sin campo visible; 2ª: campo abierto tras tocar el icono.
          return inputCalls == 1 ? null : 'id=search_field';
        },
        resolveActionSurface: (kind) async =>
            kind == 'search' ? 'id=search_icon' : null,
      );
      final plan = TaskPlan(goal: 'abre YouTube y busca X', steps: const [
        TaskStep(id: 'wq', semanticAction: 'writeQuery'),
      ]);
      final results = await o.run(plan);
      expect(results.first.status, TaskStepStatus.completed);
      expect(tapLog, ['id=search_icon']);
    });

    test('submitSearch sin botón → completedUnverified (búsqueda en vivo)', () async {
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (_) async => true,
        resolveActionSurface: (_) async => null,
      );
      final plan = TaskPlan(goal: 'abre YouTube y busca X', steps: const [
        TaskStep(id: 'ss', semanticAction: 'submitSearch'),
      ]);
      final results = await o.run(plan);
      expect(results.first.status, TaskStepStatus.completedUnverified);
    });

    test('"ve a YouTube y busca X" → app desde "ve a"', () async {
      final launchLog = <String>[];
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        launchApp: (app) async {
          launchLog.add(app);
          return true;
        },
        tap: (_) async => true,
        writeText: (_, __) async => true,
        resolveInputSurface: () async => 'id=search_field',
        resolveActionSurface: (kind) async =>
            kind == 'search' ? 'id=search_icon' : null,
      );
      final plan = const TaskPlanner().plan('ve a YouTube y busca X');
      expect(plan, isNotNull);
      await o.run(plan!);
      expect(launchLog, ['youtube']);
    });
  });

  group('TaskOrchestrator · T2.9-select selección de resultado', () {
    SearchResultCandidate cand(String title, int ordinal) =>
        SearchResultCandidate(
          ordinal: ordinal,
          title: title,
          subtitle: '',
          resourceId: '',
          bounds: const NanoBounds(left: 0, top: 0, right: 100, bottom: 100),
          packageName: '',
          confidence: 0.8,
          source: SearchResultSource.accessibility,
          selector: 'text=$title',
        );

    test('"abre el segundo resultado" → ordinal 2 → tap grounded', () async {
      String? tapped;
      ResultTarget? received;
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (sel) async {
          tapped = sel;
          return true;
        },
        resolveResult: (target) async {
          received = target;
          return ResultResolved(cand('Result B', 2));
        },
      );
      final plan = const TaskPlanner().plan('abre el segundo resultado');
      final results = await o.run(plan!);
      expect(results.first.status, TaskStepStatus.completedUnverified);
      expect(received, isA<ResultOrdinal>());
      expect((received as ResultOrdinal).ordinal, 2);
      expect(tapped, 'text=Result B');
    });

    test('"abre el resultado que dice NanoRuntime" → texto → tap grounded', () async {
      String? tapped;
      ResultTarget? received;
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (sel) async {
          tapped = sel;
          return true;
        },
        resolveResult: (target) async {
          received = target;
          return ResultResolved(cand('NanoRuntime', 1));
        },
      );
      final plan = const TaskPlanner().plan(
        'abre el resultado que dice NanoRuntime',
      );
      final results = await o.run(plan!);
      expect(received, isA<ResultText>());
      expect((received as ResultText).text, 'NanoRuntime');
      expect(tapped, 'text=NanoRuntime');
    });

    test('ordinal inexistente → needsMoreEvidence (no tap)', () async {
      var tapped = false;
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (_) async {
          tapped = true;
          return true;
        },
        resolveResult: (_) async => const ResultNotFound(),
      );
      final plan = const TaskPlanner().plan('abre el segundo resultado');
      final results = await o.run(plan!);
      expect(results.first.status, TaskStepStatus.needsMoreEvidence);
      expect(tapped, isFalse);
    });

    test('resultado ambiguo → needsMoreEvidence (clarificación, no tap)', () async {
      var tapped = false;
      final o = TaskOrchestrator(
        listNotifications: () async => [],
        openUrl: (_) async => false,
        writeFile: (_, __) async => false,
        tap: (_) async {
          tapped = true;
          return true;
        },
        resolveResult: (_) async => ResultAmbiguous([
          cand('A', 1),
          cand('B', 2),
        ]),
      );
      final plan = const TaskPlanner().plan(
        'abre el resultado que dice X',
      );
      final results = await o.run(plan!);
      expect(results.first.status, TaskStepStatus.needsMoreEvidence);
      expect(tapped, isFalse);
    });
  });
}
