import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../linux/linux_distribution_registry.dart';
import '../services/nano_runtime_api.dart';
import 'action_path_router.dart';
import 'action_verifier.dart';
import 'agent_executor.dart';
import 'agent_tool_dispatcher.dart';
import 'experience_cache.dart';
import 'stability_gate.dart';
import 'tool_registry.dart';

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
