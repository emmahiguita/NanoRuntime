import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/rootfs_manager.dart';
import '../../../../core/services/shell_executor.dart';
import '../../../../core/services/terminal_dependencies.dart';
import '../../../terminal/i_bin_executor.dart';
import 'linux_action_verifier.dart';
import 'linux_automation_port.dart';
import 'linux_process_supervisor.dart';
import 'linux_security_policy.dart';
import 'nanoshell_linux_automation_executor.dart';

/// Proveedor base del motor IBinExecutor para toda la aplicación.
///
/// Permite inyección de dependencias limpia (DIP) y sobreescritura con Mocks
/// en tests unitarios sin tocar código de producción.
final binExecutorProvider = Provider<IBinExecutor>((ref) {
  final shell = TerminalDependencies.instance.shell;
  if (shell != null) {
    return shell;
  }
  return ShellExecutor(rootfs: RootfsManager.instance);
});

/// Proveedor de la política de seguridad y confinamiento de rutas.
final linuxSecurityPolicyProvider = Provider<LinuxSecurityPolicy>((ref) {
  return const LinuxSecurityPolicy();
});

/// Proveedor del verificador de postcondiciones (EXECUTED ≠ VERIFIED).
final linuxActionVerifierProvider = Provider<LinuxActionVerifier>((ref) {
  return LinuxActionVerifier(binExecutor: ref.watch(binExecutorProvider));
});

/// Proveedor del supervisor de procesos en streaming.
final linuxProcessSupervisorProvider = Provider<LinuxProcessSupervisor>((ref) {
  return LinuxProcessSupervisor(binExecutor: ref.watch(binExecutorProvider));
});

/// Proveedor principal del puerto de automatización Linux (ILinuxAutomationExecutor).
///
/// Expone el motor Linux al cerebro de automatización (Koog/Planner/Dispatcher)
/// garantizando 100% Clean Architecture, Inversión de Dependencias y cero cuellos de botella.
final linuxAutomationExecutorProvider = Provider<ILinuxAutomationExecutor>((ref) {
  return NanoshellLinuxAutomationExecutor(
    binExecutor: ref.watch(binExecutorProvider),
    securityPolicy: ref.watch(linuxSecurityPolicyProvider),
    verifier: ref.watch(linuxActionVerifierProvider),
    supervisor: ref.watch(linuxProcessSupervisorProvider),
  );
});
