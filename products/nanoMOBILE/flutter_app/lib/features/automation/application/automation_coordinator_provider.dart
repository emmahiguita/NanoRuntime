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
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';
import 'package:nanoai/features/automation/engine/perception/surface_resolvers.dart';
import 'package:nanoai/features/automation/engine/perception/search_result_resolver.dart';
import 'package:nanoai/features/automation/engine/system/installed_app_catalog.dart';

import '../ledger/action_ledger_provider.dart';
import 'automation_coordinator.dart';
import 'automation_planner_provider.dart';

/// Coordinator del módulo con el planner LLM REAL inyectado — el motor
/// AUTÓNOMO reutilizable. Las fuentes de objetivo (chat, notificaciones, voz,
/// eventos, scheduler, C10+) consumen este provider para invocar el MISMO
/// motor con `execute(goal)`. Es la fuente de verdad de la DI del módulo.
final automationCoordinatorProvider = Provider<AutomationCoordinator>((ref) {
  // Observación de la pantalla actual (Accessibility → ScreenGraph). Fuente
  // ÚNICA del snapshot para los resolvers de superficie y la verificación de
  // envío, evitando duplicar el boilerplate snapshot→ScreenGraph.
  Future<ScreenGraph?> currentGraph() async {
    final snap = await ref.read(agentExecutorProvider).snapshot();
    if (snap == null || snap.isEmpty) return null;
    return ScreenGraph.fromSnapshot(snap);
  }

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
        final dispatcher = ref.read(agentDispatcherProvider);
        // Destino de sistema primero (Ajustes/Bluetooth/WiFi → open_system
        // allowlisted). "Ve a Ajustes y busca X" NO es launch_app: es un intent
        // oficial de sistema, no una app instalada.
        final known = defaultDeterministicCatalog.forGoal('abre $appName');
        if (known != null &&
            known.steps.length == 1 &&
            known.steps.single.tool == 'open_system') {
          final dest = known.steps.single.destinationArg;
          if (dest == null) return false;
          final r = await dispatcher.runToolGuarded(
            ToolCall(tool: 'open_system', args: {'destination': dest}),
          );
          return !r.feedback.startsWith('[');
        }
        // Resolver nombre de app → packageName real (el dispatcher launch_app
        // espera package, no nombre). Evita "whatsapp" inválido.
        final catalog = ref.read(installedAppCatalogProvider);
        final match = await catalog.findApp(appName);
        // Seguridad: ante AppMatchAmbiguous NO se elige `candidates.first` a
        // ciegas (WhatsApp vs WhatsApp Business). Solo se lanza si la resolución
        // es ÚNICA; la ambigüedad la resuelve Candidate-First (Koog) aguas
        // arriba con evidencia contextual, o se reporta sin lanzar.
        final String? pkg =
            match is AppMatchResolved ? match.app.packageName : null;
        if (pkg == null) return false;
        final r = await dispatcher.runToolGuarded(
          ToolCall(tool: 'launch_app', args: {'packageName': pkg}),
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
      // T2.0 — resolución grounded de superficies UI desde el snapshot real
      // (Accessibility → ScreenGraph). Sin superficie → null (el paso reporta
      // needsMoreEvidence, no inventa selector).
      resolveInputSurface: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return const InputSurfaceResolver().resolve(g)?.selector;
      },
      resolveActionSurface: (kind) async {
        final g = await currentGraph();
        if (g == null) return null;
        return const ActionSurfaceResolver().resolve(g, kind: kind)?.selector;
      },
      // T2.7 — texto ACTUAL del campo editable (para verificar el envío
      // observando que el composer quedó vacío, no el booleano del tap).
      observeInputText: () async {
        final g = await currentGraph();
        if (g == null) return null;
        return const InputSurfaceResolver().resolve(g)?.object.text;
      },
      // T2.9-select — resolución grounded de un resultado observado
      // (ordinal/texto) desde el ScreenGraph real, nunca coordenadas.
      resolveResult: (target) async {
        final g = await currentGraph();
        if (g == null) return null;
        return const SearchResultResolver().resolve(g, target);
      },
    ),
    // A15.2: descomposición template determinista + LLM validado.
    taskDecomposer: LlmTaskDecomposer(
      client: ref.read(runtimeEngineProvider.notifier).client,
    ),
  );
});
