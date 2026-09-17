import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../executors/linux/linux_automation_executor_provider.dart';
import 'capability_router.dart';
import 'handlers/semantic_linux_tool_handler.dart';

/// Proveedor del manejador de herramientas semánticas Linux (nano.linux.*).
final semanticLinuxToolHandlerProvider =
    Provider<SemanticLinuxToolHandler>((ref) {
  return SemanticLinuxToolHandler(
    executor: ref.watch(linuxAutomationExecutorProvider),
  );
});

/// Proveedor del Router de Capacidades Multisuperficie de Nano.
///
/// Evalúa disponibilidad de superficies en tiempo real y asigna cada tarea
/// a la vía más determinista y eficiente (API -> Linux -> Browser -> A11y -> Vision).
final capabilityRouterProvider = Provider<CapabilityRouter>((ref) {
  final linuxExec = ref.watch(linuxAutomationExecutorProvider);
  return CapabilityRouter(
    isLinuxAvailable: () => linuxExec.isAvailable,
  );
});
