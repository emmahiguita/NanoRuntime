import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_decomposer.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_orchestrator.dart';
import 'package:nanoai/features/automation/engine/orchestration/task_planner.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart'
    show defaultDeterministicCatalog;
import 'package:nanoai/features/automation/engine/system/installed_app_catalog.dart';

import '../ledger/action_ledger_provider.dart';
import 'automation_coordinator.dart';
import 'automation_planner_provider.dart';

/// Coordinator del módulo con el planner LLM REAL inyectado — el motor
/// AUTÓNOMO reutilizable. Las fuentes de objetivo (chat, notificaciones, voz,
/// eventos, scheduler, C10+) consumen este provider para invocar el MISMO
/// motor con `execute(goal)`. Es la fuente de verdad de la DI del módulo.
final automationCoordinatorProvider = Provider<AutomationCoordinator>((ref) {
  return AutomationCoordinator(
    dispatcher: ref.watch(agentDispatcherProvider),
    mode: () => ref.read(settingsProvider).agentAutomationMode,
    cache: ref.watch(experienceCacheProvider),
    flowExecutor: ref.watch(nanoFlowExecutorProvider),
    ledger: ref.watch(actionLedgerProvider),
    planner: ref.watch(llmAutomationPlannerProvider),
    verifyGoal: ref.watch(goalVerifierProvider).verify,
    catalog: defaultDeterministicCatalog,
    objectMemory: NanoObjectMemory(),
    // A13.6: compartir la instancia de memoria actualizada con el PerceptionMux
    // (vía el notifier), eliminando el split-brain.
    onMemoryUpdate: (m) => ref.read(objectMemoryProvider.notifier).replace(m),
    // A8: percepción orquestada real (accesibilidad vía ScreenGraph).
    perceptionMux: ref.watch(perceptionMuxProvider),
    // A2: resuelve "abre <app>" con package REAL del PackageManager.
    appLaunch: ref.watch(appLaunchResolverProvider),
    // A13.5: planificador Candidate-First de producción (0 LLM goals conocidos).
    candidateFirst: ref.watch(candidateFirstPlannerProvider),
    // A15.0: orquestador cross-app multi-paso con data flow tipado (0 LLM).
    taskPlanner: const TaskPlanner(),
    taskOrchestrator: TaskOrchestrator(
      listNotifications: () =>
          NanoRuntimeApi.instance.listActiveNotifications(),
      openUrl: (url) => NanoRuntimeApi.instance.openUrl(url),
      writeFile: (path, content) async {
        final dispatcher = ref.read(agentDispatcherProvider);
        final r = await dispatcher.runToolGuarded(
          ToolCall(
            tool: 'linux.writeFile',
            text: path,
            args: {'content': content},
          ),
        );
        return !r.feedback.startsWith('[');
      },
      // A15.4: fuentes UI (delegan al dispatcher, que ya tiene governance).
      launchApp: (appName) async {
        // Resolver nombre de app → packageName real (el dispatcher launch_app
        // espera package, no nombre). Evita "whatsapp" inválido.
        final catalog = ref.read(installedAppCatalogProvider);
        final match = await catalog.findApp(appName);
        String? pkg;
        if (match is AppMatchResolved) {
          pkg = match.app.packageName;
        } else if (match is AppMatchAmbiguous && match.candidates.isNotEmpty) {
          pkg = match.candidates.first.packageName;
        }
        if (pkg == null) return false;
        final dispatcher = ref.read(agentDispatcherProvider);
        final r = await dispatcher.runToolGuarded(
          ToolCall(tool: 'launch_app', text: pkg),
        );
        return !r.feedback.startsWith('[');
      },
      tap: (selector) async {
        final dispatcher = ref.read(agentDispatcherProvider);
        final r = await dispatcher.runToolGuarded(
          ToolCall(tool: 'tap', selector: selector),
        );
        return !r.feedback.startsWith('[');
      },
      writeText: (selector, text) async {
        final dispatcher = ref.read(agentDispatcherProvider);
        final r = await dispatcher.runToolGuarded(
          ToolCall(tool: 'write', selector: selector, text: text),
        );
        return !r.feedback.startsWith('[');
      },
    ),
    // A15.2: descomposición template determinista + LLM validado.
    taskDecomposer: LlmTaskDecomposer(
      client: ref.read(runtimeEngineProvider.notifier).client,
    ),
  );
});
