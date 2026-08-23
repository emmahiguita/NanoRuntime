import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/linux/linux_distribution_registry.dart';
import '../../../core/services/nano_runtime_api.dart';
import 'execution/action_path_router.dart';
import 'execution/action_verifier.dart';
import 'execution/agent_executor.dart';
import 'execution/agent_tool_dispatcher.dart';
import 'memory/experience_cache.dart';
import 'execution/goal_verifier.dart';
import 'execution/nano_flow.dart';
import 'execution/stability_gate.dart';
import 'execution/tool_registry.dart';

/// Composition root del agente (DIP/SRP): TODAS las dependencias del agente
/// se construyen UNA vez aquí con sus implementaciones reales y se inyectan a
/// los consumidores. Regla: ningún consumidor instancia `new NanoAgentExecutor`
/// / `new ActionVerifier` / `new AgentToolDispatcher` — los recibe por
/// constructor o por provider.
///
/// El cableado es el del runtime real (canal `com.nanoai/agent`); los tests
/// inyectan fakes en su lugar (ver chat_provider `toolDispatcher:`).

/// Ejecutor real sobre el canal de accesibilidad.
final agentExecutorProvider = Provider<AgentExecutor>((ref) {
  return NanoAgentExecutor(api: NanoRuntimeApi.instance);
});

/// Verificador de postcondiciones que comparte el snapshot del executor.
final agentVerifierProvider = Provider<AgentVerifier>((ref) {
  return ActionVerifier(snapshotFn: ref.watch(agentExecutorProvider).snapshot);
});

/// Política de gobernanza con el registro canónico de tools.
final policyEngineProvider = Provider<PolicyEngine>((ref) {
  return PolicyEngine(registry: ToolRegistry.builtin);
});

/// Dispatcher con TODAS sus dependencias inyectadas (sin defaults internos
/// en producción). El chat lo recibe vía `chatProvider`.
final agentDispatcherProvider = Provider<AgentToolDispatcher>((ref) {
  return AgentToolDispatcher(
    executor: ref.watch(agentExecutorProvider),
    registry: ToolRegistry.builtin,
    policy: ref.watch(policyEngineProvider),
    verifier: ref.watch(agentVerifierProvider),
    router: ref.watch(actionPathRouterProvider),
  );
});

/// Estabilidad del árbol semántico (C4): espera asentamiento bounded.
final stabilityGateProvider = Provider<StabilityGate>((ref) {
  return StabilityGate(snapshotFn: ref.watch(agentExecutorProvider).snapshot);
});

/// Router de ruta de ejecución (C6): comparte el estado real de Linux.
final actionPathRouterProvider = Provider<ActionPathRouter>((ref) {
  return ActionPathRouter(
    // Linux disponible cuando hay distribuciones registradas en el
    // subsistema (termux/kali/ubuntu instalados).
    linuxAvailable: () =>
        LinuxDistributionRegistry.instance.getAllDistributions().isNotEmpty,
  );
});

/// Memoria de ejecuciones verificadas (C7): única por app, en memoria.
final experienceCacheProvider = Provider<ExperienceCache>((ref) {
  return ExperienceCache();
});

/// Verificador del objetivo final (C3), sobre el MISMO executor del dispatcher.
final goalVerifierProvider = Provider<GoalVerifier>((ref) {
  return GoalVerifier(executor: ref.watch(agentExecutorProvider));
});

/// Ejecutor de flujos deterministas (C8): flujo verificado → ejecución sin
/// LLM, con la misma gobernanza que el plan del LLM.
final nanoFlowExecutorProvider = Provider<NanoFlowExecutor>((ref) {
  return NanoFlowExecutor(
    dispatcher: ref.watch(agentDispatcherProvider),
    goalVerifier: ref.watch(goalVerifierProvider),
  );
});
