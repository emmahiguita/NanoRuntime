import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/nano_runtime_api.dart';
import 'action_verifier.dart';
import 'agent_executor.dart';
import 'agent_tool_dispatcher.dart';
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
  );
});
