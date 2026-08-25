import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart'
    show defaultDeterministicCatalog;
import 'package:nanoai/features/automation/engine/perception/perception_mux.dart'
    show PerceptionMux;

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
    // C12: sin fuente de percepción de pantalla conectada aún (se wirea el
    // AccessibilityPerception en el device). Mux vacío = no inventa.
    perceptionMux: const PerceptionMux([]),
    // A2: resuelve "abre <app>" con package REAL del PackageManager.
    appLaunch: ref.watch(appLaunchResolverProvider),
  );
});
